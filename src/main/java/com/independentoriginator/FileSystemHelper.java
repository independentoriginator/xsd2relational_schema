package com.independentoriginator;

import java.io.IOException;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;

public class FileSystemHelper {
    public static void gatherTheSpecifiedFilesWithinTheDirectory(Path dir, String globPattern, List<Path> targetFiles, boolean relativizeFileNames)
            throws IOException {
        gatherFilesWithinTheDirectory(dir, globPattern, targetFiles, relativizeFileNames, dir);
    }

    private static void gatherFilesWithinTheDirectory(Path dir, String globPattern, List<Path> targetFiles, boolean relativizeFileNames, Path rootDir)
            throws IOException {
        try (DirectoryStream<Path> stream = Files.newDirectoryStream(dir, globPattern)) {
            for (Path entry : stream) {
                if (Files.isRegularFile(entry)) {
                    targetFiles.add(relativizeFileNames ? rootDir.relativize(entry) : entry);
                }
            }
        }
        try (DirectoryStream<Path> stream = Files.newDirectoryStream(dir)) {
            for (Path entry : stream) {
                if (Files.isDirectory(entry)) {
                    gatherFilesWithinTheDirectory(entry, globPattern, targetFiles, relativizeFileNames, rootDir);
                }
            }
        }
    }

    public record FilePathComponents(String path, String directory, String name, String title, String extension) {}

    public static FilePathComponents splitFilePath(String filePath) {
        Path path = Paths.get(filePath);
        String directory = path.getParent().toString();
        String name = path.getFileName().toString();
        int dotIndex = name.lastIndexOf('.');
        String title = (dotIndex == -1) ? name : name.substring(0, dotIndex);
        String extension = (dotIndex == -1) ? "" : name.substring(dotIndex + 1);
        return new FilePathComponents(filePath, directory, name, title, extension);
    }
}
