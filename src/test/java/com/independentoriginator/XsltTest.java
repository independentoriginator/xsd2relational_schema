package com.independentoriginator;

import net.sf.saxon.s9api.SaxonApiException;
import org.junit.jupiter.api.Test;

import javax.xml.stream.XMLStreamException;
import java.io.IOException;
import java.net.URISyntaxException;
import java.nio.file.Path;
import java.sql.SQLException;

public class XsltTest {
    private final String xsdFileDir;

    public XsltTest() throws URISyntaxException {
        ClassLoader classLoader = getClass().getClassLoader();
        xsdFileDir = Path.of(classLoader.getResource("xsd").toURI()).toAbsolutePath().toString();
    }

    //@Test
    public void testXsdTransformation() throws SaxonApiException, IOException {
        XsdTransformer xsdTransformer = new XsdTransformer();
        // Gets an XML file with the relational schema as the result for each XSD schema in the specified directory
        xsdTransformer.transform(xsdFileDir, null);
    }

    //@Test
    public void testXmlQueriesGenerator4Oracle()
            throws SaxonApiException, IOException, SQLException, URISyntaxException, XMLStreamException {
        XmlTableQueriesGenerator xmlTableQueriesGenerator = new XmlTableQueriesGenerator();
        xmlTableQueriesGenerator.generate(xsdFileDir, null, "oracle");
    }

    @Test
    public void testXmlTableFunctionsGenerator4Oracle()
            throws SaxonApiException, IOException, SQLException, URISyntaxException, XMLStreamException {
        XmlTableQueriesGenerator xmlTableQueriesGenerator = new XmlTableQueriesGenerator();
        xmlTableQueriesGenerator.generateTableFunctionPackages(xsdFileDir, null, "oracle");
    }
}