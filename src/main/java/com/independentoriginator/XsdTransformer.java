package com.independentoriginator;

import net.sf.saxon.s9api.SaxonApiException;
import java.io.IOException;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

public class XsdTransformer {
    private final XsltExecutor xsltExecutor;

    public XsdTransformer() {
        xsltExecutor = new XsltExecutor();
    }

    // Gets an XML file with the relational schema as the result for each XSD schema in the specified directory
    public void transform(String xsdFileDir, String resultXMLFileDir) throws SaxonApiException, IOException {
        List<Path> targetFiles = new ArrayList<>();
        FileSystemHelper.gatherTheSpecifiedFilesWithinTheDirectory(Paths.get(xsdFileDir).toRealPath(), "*.xsd", targetFiles, false);
        for (Path entry : targetFiles) {
            xsltExecutor.transform(entry.toString(), null, resultXMLFileDir, null);
        }
    }
}