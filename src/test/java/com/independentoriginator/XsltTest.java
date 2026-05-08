package com.independentoriginator;

import net.sf.saxon.s9api.SaxonApiException;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.net.URISyntaxException;
import java.net.URL;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

public class XsltTest {
    public void gatherTargetFilesWithinTheDirectory(Path dir, String globPattern, List<Path> targetFiles) throws IOException {
        try (DirectoryStream<Path> stream = Files.newDirectoryStream(dir, globPattern)) {
            for (Path entry : stream) {
                if (Files.isRegularFile(entry)) {
                    targetFiles.add(entry);
                }
            }
        }

        try (DirectoryStream<Path> stream = Files.newDirectoryStream(dir)) {
            for (Path entry : stream) {
                if (Files.isDirectory(entry)) {
                    gatherTargetFilesWithinTheDirectory(entry, globPattern, targetFiles);
                }
            }
        }
    }

    @Test
    public void testDataFiles() throws SaxonApiException, IOException, URISyntaxException {
        URL xsdDir = getClass().getClassLoader().getResource(".");
        String globPattern = "*.xsd";
        List<Path> targetFiles = new ArrayList<>();

        gatherTargetFilesWithinTheDirectory(Paths.get(xsdDir.toURI()), globPattern, targetFiles);

        XsltExecutor xsltExecutor = new XsltExecutor();
        for (Path entry : targetFiles) {
            xsltExecutor.transform(entry.toString(), null, null);
        }
    }
}