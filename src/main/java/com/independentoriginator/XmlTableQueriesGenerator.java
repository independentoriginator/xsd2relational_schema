package com.independentoriginator;

import net.sf.saxon.s9api.SaxonApiException;

import javax.xml.stream.XMLStreamException;
import java.io.IOException;
import java.net.URISyntaxException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.sql.*;

public class XmlTableQueriesGenerator {
    public void generate(String xsdFileDir, String resultFileDir, String targetDatabaseVendor)
            throws SaxonApiException, IOException, SQLException, URISyntaxException, XMLStreamException {
        Files.createDirectories(Paths.get(resultFileDir));

        // Transform XSD to XML with the relational schemas
        XsdTransformer xsdTransformer = new XsdTransformer();
        xsdTransformer.transform(xsdFileDir, null);

        // Generate database schema for storing the XSD relational schemas metadata
        DatabaseConnection dbConnection = new DatabaseConnection(targetDatabaseVendor);
        DatabaseSchemaGenerator dbSchemaGenerator = new DatabaseSchemaGenerator(dbConnection);
        dbSchemaGenerator.generateDatabaseSchema(xsdFileDir);

/*


            sqlScript = Files.readString(Paths.get(vendorFileDir, "makeXmlTableQueries.sql"));

            try (PreparedStatement stmt = dbConnection.prepareStatement(sqlScript)) {
                // Bind the array
                stmt.setArray(1, xmlFileSqlArray);

                boolean isResultSet = stmt.execute();
                while (true) {
                    if (isResultSet) {
                        try (ResultSet rs = stmt.getResultSet()) {
                            while (rs.next()) {
                                String name = rs.getString("file_name");
                                System.out.println("file_name: " + name);
                            }
                        }
                    } else if (stmt.getUpdateCount() == -1) {
                        // End of the script reached: no more results available
                        break;
                    }
                    // Move to the next result in the batch
                    isResultSet = stmt.getMoreResults();
                }
            }*/

    }
}

