package rotation

import (
	"archive/zip"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sync"
	"time"
)

type FolderManager struct {
	baseDir        string
	currentFolder  string
	currentHour    string
	maxBodySize    int64
	mu             sync.Mutex
}

func NewFolderManager(baseDir string, maxBodySize int64) (*FolderManager, error) {
	if err := os.MkdirAll(baseDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create base directory: %w", err)
	}

	fm := &FolderManager{
		baseDir:     baseDir,
		maxBodySize: maxBodySize,
	}

	if err := fm.rotateIfNeeded(); err != nil {
		return nil, err
	}

	return fm, nil
}

func (fm *FolderManager) getCurrentHourFolder() string {
	return time.Now().UTC().Format("2006-01-02-15")
}

func (fm *FolderManager) rotateIfNeeded() error {
	currentHour := fm.getCurrentHourFolder()
	
	if fm.currentHour != currentHour {
		oldFolder := fm.currentFolder
		oldHour := fm.currentHour
		
		fm.currentHour = currentHour
		fm.currentFolder = filepath.Join(fm.baseDir, currentHour)
		
		if err := os.MkdirAll(fm.currentFolder, 0755); err != nil {
			return fmt.Errorf("failed to create hour folder: %w", err)
		}
		
		if oldFolder != "" && oldHour != "" {
			go fm.zipAndCleanup(oldFolder, oldHour)
		}
	}
	
	return nil
}

func (fm *FolderManager) zipAndCleanup(folderPath, hourLabel string) {
	zipPath := filepath.Join(fm.baseDir, hourLabel+".zip")
	
	if err := fm.zipFolder(folderPath, zipPath); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: Failed to zip folder %s: %v\n", folderPath, err)
		return
	}
	
	if err := os.RemoveAll(folderPath); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: Failed to remove folder %s: %v\n", folderPath, err)
		return
	}
	
	fmt.Printf("INFO: Zipped and cleaned up folder: %s -> %s\n", folderPath, zipPath)
}

func (fm *FolderManager) zipFolder(source, target string) error {
	zipFile, err := os.Create(target)
	if err != nil {
		return err
	}
	defer zipFile.Close()

	archive := zip.NewWriter(zipFile)
	defer archive.Close()

	return filepath.Walk(source, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if info.IsDir() {
			return nil
		}

		relPath, err := filepath.Rel(source, path)
		if err != nil {
			return err
		}

		writer, err := archive.Create(relPath)
		if err != nil {
			return err
		}

		file, err := os.Open(path)
		if err != nil {
			return err
		}
		defer file.Close()

		_, err = io.Copy(writer, file)
		return err
	})
}

func (fm *FolderManager) SaveBody(requestID string, body io.Reader) (string, int64, error) {
	fm.mu.Lock()
	defer fm.mu.Unlock()

	if err := fm.rotateIfNeeded(); err != nil {
		return "", 0, err
	}

	fileName := fmt.Sprintf("body_%s.dat", requestID)
	filePath := filepath.Join(fm.currentFolder, fileName)

	file, err := os.Create(filePath)
	if err != nil {
		return "", 0, fmt.Errorf("failed to create body file: %w", err)
	}
	defer file.Close()

	limitedReader := io.LimitReader(body, fm.maxBodySize)
	written, err := io.Copy(file, limitedReader)
	if err != nil {
		os.Remove(filePath)
		return "", 0, fmt.Errorf("failed to write body: %w", err)
	}

	if written == 0 {
		os.Remove(filePath)
		return "", 0, nil
	}

	return filePath, written, nil
}

func (fm *FolderManager) GetCurrentFolder() string {
	fm.mu.Lock()
	defer fm.mu.Unlock()
	return fm.currentFolder
}
