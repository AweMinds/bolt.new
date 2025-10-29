import JSZip from 'jszip';
import type { WebContainer } from '@webcontainer/api';
import type { FileMap } from '~/lib/stores/files';
import { WORK_DIR } from '~/utils/constants';
import { createScopedLogger } from '~/utils/logger';

const logger = createScopedLogger('FileExport');

/**
 * Download all project files as a ZIP archive using FileMap
 */
export async function downloadProjectAsZip(
  webcontainer: WebContainer,
  fileMap: FileMap,
  projectName: string = 'project',
) {
  try {
    logger.debug('Starting project export as ZIP');

    const zip = new JSZip();
    let fileCount = 0;

    // Iterate through all files in the FileMap
    for (const [filePath, dirent] of Object.entries(fileMap)) {
      // Only process files (not folders) that are under WORK_DIR
      if (dirent?.type !== 'file' || !filePath.startsWith(WORK_DIR)) {
        continue;
      }

      // Skip binary files
      if (dirent.isBinary) {
        logger.debug(`Skipping binary file: ${filePath}`);
        continue;
      }

      // Get relative path by removing WORK_DIR prefix
      const relativePath = filePath.substring(WORK_DIR.length + 1);

      // Add file to ZIP using content from FileMap
      zip.file(relativePath, dirent.content);
      fileCount++;
      logger.debug(`Added file to ZIP: ${relativePath}`);
    }

    logger.debug(`Added ${fileCount} files to ZIP`);

    if (fileCount === 0) {
      throw new Error('No files found to export');
    }

    // Generate ZIP blob
    logger.debug('Generating ZIP file');
    const blob = await zip.generateAsync({ type: 'blob' });

    // Trigger download
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5);
    const filename = `${projectName}_${timestamp}.zip`;

    triggerDownload(blob, filename);

    logger.debug(`Project exported successfully as ${filename}`);
  } catch (error) {
    logger.error('Failed to export project:', error);
    throw error;
  }
}

/**
 * Download a single file using FileMap
 */
export async function downloadSingleFile(webcontainer: WebContainer, fileMap: FileMap, filePath: string) {
  try {
    logger.debug(`Downloading file: ${filePath}`);

    // Get file from FileMap
    const dirent = fileMap[filePath];

    if (!dirent || dirent.type !== 'file') {
      throw new Error(`File not found: ${filePath}`);
    }

    if (dirent.isBinary) {
      throw new Error(`Cannot download binary file: ${filePath}`);
    }

    // Create blob from file content
    const blob = new Blob([dirent.content], { type: 'text/plain;charset=utf-8' });

    // Extract filename from path
    const filename = filePath.split('/').pop() || 'file';

    triggerDownload(blob, filename);

    logger.debug(`File downloaded successfully: ${filename}`);
  } catch (error) {
    logger.error(`Failed to download file ${filePath}:`, error);
    throw error;
  }
}

/**
 * Trigger browser download of a blob
 */
function triggerDownload(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);

  // Clean up the URL object
  setTimeout(() => URL.revokeObjectURL(url), 100);
}
