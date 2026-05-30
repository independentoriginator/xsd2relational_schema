package com.independentoriginator;

import javax.xml.stream.XMLInputFactory;
import javax.xml.stream.XMLStreamConstants;
import javax.xml.stream.XMLStreamException;
import javax.xml.stream.XMLStreamReader;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.sql.*;
import java.util.ArrayList;
import java.util.List;
import java.math.BigDecimal;

public class DatabaseSchemaGenerator {
    private final DatabaseConnection dbConnection;

    public DatabaseSchemaGenerator(DatabaseConnection dbConnection) {
        this.dbConnection = dbConnection;
    }

    public void generateDatabaseSchema(String xmlFileDir)
            throws SQLException, IOException, XMLStreamException {
        // Prepare the tables for storing the XSD relational schemas metadata
        dbConnection.getPreparedSqlScript("prepareXsdSchemaTables.sql").execute();

        // Gather the generated XML files with the XSD relational schemas data
        List<Path> xmlFiles = new ArrayList<>();
        Path xmlFileDirPath = Paths.get(xmlFileDir);
        FileSystemHelper.gatherTheSpecifiedFilesWithinTheDirectory(xmlFileDirPath, "*.xml", xmlFiles, false);

        // Load XML files data into the database tables
        for (Path xmlFile : xmlFiles) {
            loadXsdSchema(xmlFileDirPath.relativize(xmlFile).toString(), xmlFile.toString());
        }

        // Commit the transaction explicitly
        dbConnection.getConnection().commit();
    }

    private void loadXsdSchema(String xmlFileName, String xmlFilePath)
            throws SQLException, IOException, XMLStreamException {
        PreparedStatement insertSchemaStatement = dbConnection.getPreparedSqlScript("insertXsdSchema.sql");
        SQLXML sqlXml = dbConnection.getConnection().createSQLXML();
        try (FileInputStream iStream = new FileInputStream(xmlFilePath);
             OutputStream oStream = sqlXml.setBinaryStream()) {
            iStream.transferTo(oStream);
        }
        insertSchemaStatement.setString(1, xmlFileName);
        insertSchemaStatement.setSQLXML(2, sqlXml);
        insertSchemaStatement.executeUpdate();
        sqlXml.free();
        System.out.println(xmlFileName);
        try (ResultSet rs = insertSchemaStatement.getGeneratedKeys()) {
            if (rs.next()) {
                BigDecimal xsdSchemaId = rs.getBigDecimal(1);
                System.out.println(xsdSchemaId);

                PreparedStatement insertNamespaceStatement = dbConnection.getPreparedSqlScript("insertXsdNamespace.sql");
                insertNamespaceStatement.setBigDecimal(1, xsdSchemaId);
                PreparedStatement insertTableStatement = dbConnection.getPreparedSqlScript("insertXsdTable.sql");
                insertTableStatement.setBigDecimal(1, xsdSchemaId);
                PreparedStatement insertColumnStatement = dbConnection.getPreparedSqlScript("insertXsdColumn.sql");
                insertColumnStatement.setBigDecimal(1, xsdSchemaId);

                // Parse XML file using Java's Streaming API for XML (StAX)
                XMLInputFactory factory = XMLInputFactory.newInstance();
                FileInputStream inputStream = new FileInputStream(xmlFilePath);
                XMLStreamReader reader = factory.createXMLStreamReader(inputStream);
                while (reader.hasNext()) {
                    int eventType = reader.next();
                    switch (eventType) {
                        case XMLStreamConstants.START_ELEMENT:
                            switch (reader.getLocalName()) {
                                case "column":
                                    insertColumnStatement.setNull(7, Types.VARCHAR);
                                    insertColumnStatement.setNull(8, Types.INTEGER);
                                    insertColumnStatement.setNull(9, Types.INTEGER);
                                    insertColumnStatement.setNull(10, Types.INTEGER);
                                    insertColumnStatement.setNull(11, Types.INTEGER);
                                    insertColumnStatement.setNull(12, Types.INTEGER);

                                    for (int i = 0; i < reader.getAttributeCount(); i++) {
                                        // column position
                                        insertColumnStatement.setInt(5, i + 1);
                                        switch(reader.getAttributeLocalName(i)) {
                                            case "path":
                                                insertColumnStatement.setString(3, reader.getAttributeValue(i));
                                                break;
                                            case "name":
                                                insertColumnStatement.setString(4, reader.getAttributeValue(i));
                                                break;
                                            case "type":
                                                insertColumnStatement.setString(6, reader.getAttributeValue(i));
                                                break;
                                            case "pattern":
                                                insertColumnStatement.setString(7, reader.getAttributeValue(i));
                                                break;
                                            case "length":
                                                insertColumnStatement.setInt(8, Integer.parseInt(reader.getAttributeValue(i)));
                                                break;
                                            case "max_length":
                                                insertColumnStatement.setInt(9, Integer.parseInt(reader.getAttributeValue(i)));
                                                break;
                                            case "total_digits":
                                                insertColumnStatement.setInt(10, Integer.parseInt(reader.getAttributeValue(i)));
                                                break;
                                            case "fraction_digits":
                                                insertColumnStatement.setInt(11, Integer.parseInt(reader.getAttributeValue(i)));
                                                break;
                                            case "is_multivalued":
                                                insertColumnStatement.setInt(12, Integer.parseInt(reader.getAttributeValue(i)));
                                                break;
                                        }
                                    }
                                    break;
                                case "table":
                                    insertTableStatement.setNull(3, java.sql.Types.VARCHAR);
                                    for (int i = 0; i < reader.getAttributeCount(); i++) {
                                        switch(reader.getAttributeLocalName(i)) {
                                            case "path":
                                                String tablePath = reader.getAttributeValue(i);
                                                insertTableStatement.setString(2, tablePath);
                                                insertColumnStatement.setString(2, tablePath);
                                                break;
                                            case "masterTable":
                                                insertTableStatement.setString(3, reader.getAttributeValue(i));
                                                break;
                                        }
                                    }
                                    break;
                                case "relational_schema":
                                    for (int i = 0; i < reader.getNamespaceCount(); i++) {
                                        insertNamespaceStatement.setString(2, reader.getNamespaceURI(i));
                                        insertNamespaceStatement.setString(3, reader.getNamespacePrefix(i));
                                        insertNamespaceStatement.executeUpdate();
                                    }
                                    break;
                            }
                            break;
                        case XMLStreamConstants.END_ELEMENT:
                            switch (reader.getLocalName()) {
                                case "column":
                                    insertColumnStatement.executeUpdate();
                                    break;
                                case "table":
                                    insertTableStatement.executeUpdate();
                                    break;
                            }
                            break;
                    }
                }

            }
        }
    }
}
