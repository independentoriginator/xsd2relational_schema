package com.independentoriginator;

import net.sf.saxon.s9api.*;

import javax.xml.transform.stream.StreamSource;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.NoSuchFileException;
import java.nio.file.Path;
import java.nio.file.Paths;

public class XsltExecutor {
    private final Processor processor;

    public XsltExecutor() {
        processor = new Processor(false);
    }

    public void transform(String xmlFile, String xsltFile, String resultFileDir, String resultFileName)
            throws SaxonApiException, IOException {
        // XSLT compilation
        XsltCompiler compiler = processor.newXsltCompiler();
        String xslt = (xsltFile != null) ? xsltFile : "xslt/xsd2relational_schema.xsl";
        InputStream xsltInputStream = getClass().getClassLoader().getResourceAsStream(xslt);
        if (xsltInputStream == null) {
            throw new IllegalArgumentException("XSLT file not found: " + xslt);
        }
        XsltExecutable stylesheet = compiler.compile(new StreamSource(xsltInputStream));

        // Transformer creation
        XsltTransformer transformer = stylesheet.load();

        // Source
        Path inputFile = Paths.get(xmlFile);
        InputStream xmlInputStream;
        try {
            xmlInputStream = Files.newInputStream(inputFile);
        } catch (NoSuchFileException e) {
            throw new IllegalArgumentException("XML input file not found: " + xmlFile);
        }
        XdmNode source = processor.newDocumentBuilder().build(new StreamSource(xmlInputStream));
        transformer.setInitialContextNode(source);

        // Destination
        Path outputFile;
        if (resultFileName != null) {
            if (resultFileDir != null)
                outputFile = Paths.get(resultFileDir, resultFileName);
            else
                outputFile = Paths.get(resultFileName);
        } else {
            // Input file path splitting
            FileSystemHelper.FilePathComponents inputFilePathComponents = FileSystemHelper.splitFilePath(xmlFile);
            outputFile = Paths.get(
                    (resultFileDir == null) ? inputFilePathComponents.directory() : resultFileDir,
                    inputFilePathComponents.title() + ".xml");
        }
        Serializer out = processor.newSerializer(outputFile.toFile());
        transformer.setDestination(out);

        // Transformation
        transformer.transform();
    }
}
