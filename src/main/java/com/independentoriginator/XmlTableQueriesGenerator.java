package com.independentoriginator;

import net.sf.saxon.s9api.SaxonApiException;

import javax.xml.stream.XMLStreamException;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.Reader;
import java.net.URISyntaxException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.sql.*;

public class XmlTableQueriesGenerator {
    // Generate XML Table queries
    public void generate(String xsdFileDir, String resultFileDir, String targetDatabaseVendor)
            throws SaxonApiException, IOException, SQLException, URISyntaxException, XMLStreamException {
        // Transform XSD to XML with the relational schemas
        XsdTransformer xsdTransformer = new XsdTransformer();
        xsdTransformer.transform(xsdFileDir, null);

        // Generate database schema for storing the XSD relational schemas metadata
        try (DatabaseConnection dbConnection = new DatabaseConnection(targetDatabaseVendor)) {
            DatabaseSchemaGenerator dbSchemaGenerator = new DatabaseSchemaGenerator(dbConnection);
            dbSchemaGenerator.generateDatabaseSchema(xsdFileDir);
            // Generate target XmlTableQuery files
            String xmlQueriesDir = (resultFileDir != null && !resultFileDir.isEmpty()) ? resultFileDir : xsdFileDir;
            PreparedStatement makeXmlTableQueriesStmt = dbConnection.getPreparedSqlScript("XmlTableQueries.sql");
            makeXmlTableQueriesStmt.executeQuery();
            try (ResultSet rs = makeXmlTableQueriesStmt.getResultSet()) {
                while (rs.next()) {
                    String sourceSchemaFileName = rs.getString("file_name");
                    FileSystemHelper.FilePathComponents filePathComponents = FileSystemHelper.splitFilePath(sourceSchemaFileName);
                    String tablePath = rs.getString("table_path");
                    if (tablePath.startsWith("/")) tablePath = tablePath.substring(1);
                    tablePath = tablePath.replace("/", ".");
                    Path targetFileDir = Path.of(xmlQueriesDir, filePathComponents.directory(), filePathComponents.title());
                    Files.createDirectories(targetFileDir);
                    Clob tableQuery = rs.getClob("table_query");
                    if (tableQuery != null) {
                        try (Reader reader = tableQuery.getCharacterStream();
                             BufferedWriter writer =
                                     Files.newBufferedWriter(Path.of(targetFileDir.toString(), tablePath + ".sql"),
                                             StandardCharsets.UTF_8)) {
                            reader.transferTo(writer);
                        }
                    }
                }
            }
        }
    }

    // Generate XML Table function packages
    public void generateTableFunctionPackages(String xsdFileDir, String resultFileDir, String targetDatabaseVendor)
            throws SaxonApiException, IOException, SQLException, URISyntaxException, XMLStreamException {
        // Transform XSD to XML with the relational schemas
        XsdTransformer xsdTransformer = new XsdTransformer();
        xsdTransformer.transform(xsdFileDir, null);

        // Generate database schema for storing the XSD relational schemas metadata
        try (DatabaseConnection dbConnection = new DatabaseConnection(targetDatabaseVendor)) {
            DatabaseSchemaGenerator dbSchemaGenerator = new DatabaseSchemaGenerator(dbConnection);
            dbSchemaGenerator.generateDatabaseSchema(xsdFileDir);
            // Generate target XmlTableFunction packages
            String resultDir = (resultFileDir != null && !resultFileDir.isEmpty()) ? resultFileDir : xsdFileDir;
            PreparedStatement makeXmlTableQueriesStmt = dbConnection.getPreparedSqlScript("XmlTableQueries.sql");
            makeXmlTableQueriesStmt.executeQuery();
            try (ResultSet rs = makeXmlTableQueriesStmt.getResultSet()) {
                while (rs.next()) {
                    String sourceSchemaFileName = rs.getString("file_name");
                    FileSystemHelper.FilePathComponents filePathComponents = FileSystemHelper.splitFilePath(sourceSchemaFileName);
                    Path targetFileDir = Path.of(resultDir, filePathComponents.directory());
                    Files.createDirectories(targetFileDir);
                    String packageName = rs.getString("package_name");
                    Clob packageDef = rs.getClob("package_def");
                    if (packageDef != null) {
                        try (Reader reader = packageDef.getCharacterStream();
                             BufferedWriter writer =
                                     Files.newBufferedWriter(Path.of(targetFileDir.toString(), packageName + ".sql"),
                                             StandardCharsets.UTF_8)) {
                            reader.transferTo(writer);
                        }
                    }
                }
            }
        }
    }
}

