package com.independentoriginator;

import java.io.IOException;
import java.io.InputStream;
import java.net.URISyntaxException;
import java.net.URL;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.*;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Properties;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class DatabaseConnection implements AutoCloseable {
    private final Connection connection;
    private final Properties properties;

    public record PreparedSqlStatement(String name, PreparedStatement statement) {}
    private final List<PreparedSqlStatement> preparedStatements;

    public DatabaseConnection(String vendorName)
            throws IOException, SQLException, URISyntaxException {
        ClassLoader classLoader = getClass().getClassLoader();
        String propertiesFile = Path.of("properties", vendorName, "db.properties").toString();
        properties = new Properties();
        try (InputStream input = classLoader.getResourceAsStream(propertiesFile)) {
            if (input == null) {
                throw new IllegalArgumentException(String.format("Database properties file not found: %s", propertiesFile));
            }
            properties.load(input);
        }

        properties.put("db.vendor", vendorName);

        String dbUrl = getDatabaseProperty("db.url");
        String dbUser = getDatabaseProperty("db.user");
        String dbPassword = getDatabaseProperty("db.pass");
        if (dbUrl == null || dbUser == null) {
            throw new IllegalStateException(String.format("Database connection properties must be specified in the special resource file %s", propertiesFile));
        }

        connection = DriverManager.getConnection(dbUrl, dbUser, dbPassword);

        connection.setAutoCommit(false);

        // Prepare existing vendor SQL scripts
        this.preparedStatements = new ArrayList<>();
        URL sqlFileDir = getClass().getClassLoader().getResource("sql/" + vendorName);
        if (sqlFileDir == null) {
            throw new UnsupportedOperationException(String.format("The database vendor %s is not supported", vendorName));
        }
        Path vendorFileDir = Path.of(sqlFileDir.toURI()).toAbsolutePath();
        String dbSchema = getDatabaseProperty("db.schema");
        try (DirectoryStream<Path> stream = Files.newDirectoryStream(vendorFileDir, "*.sql")) {
            for (Path entry : stream) {
                if (Files.isRegularFile(entry)) {
                    String fileName = vendorFileDir.relativize(entry).toString();
                    String fileContent = Files.readString(entry);
                    if (dbSchema != null) {
                        fileContent = fileContent.replace("{{schema}}", dbSchema);
                    }
                    // Handle returning auto-generated keys, if any
                    String[] generatedKeys = null;
                    {
                        Pattern pattern = Pattern.compile("\\{\\{returns: (.+)\\}\\}");
                        Matcher matcher = pattern.matcher(fileContent);
                        if (matcher.find()) {
                            String substring = matcher.group(1);
                            generatedKeys = substring.split(",\\s*");
                        }
                        System.out.println(Arrays.toString(generatedKeys));
                    }
                    PreparedStatement statement =
                            (generatedKeys != null) ? connection.prepareStatement(fileContent, generatedKeys)
                                    : connection.prepareStatement(fileContent);
                    PreparedSqlStatement preparedStatement = new PreparedSqlStatement(fileName, statement);
                    this.preparedStatements.add(preparedStatement);
                }
            }
        }
    }

    public String getDatabaseProperty(String propertyName) {
        return properties.getProperty(propertyName);
    }

    public Connection getConnection() {
        return connection;
    }

    public void executeSqlScript(String sqlScript) throws SQLException {
        try (Statement statement = connection.createStatement()) {
            statement.execute(sqlScript);
        }
    }

    public PreparedStatement getPreparedSqlScript(String scriptName) {
        return preparedStatements.stream()
                .filter(sqlScript -> sqlScript.name().equals(scriptName))
                .findFirst()
                .orElseThrow(() -> new RuntimeException(String.format("SQL script not found: %s", scriptName)))
                .statement();
    }

    @Override
    public void close() throws SQLException {
        for (PreparedSqlStatement sqlStatement : preparedStatements) {
            PreparedStatement preparedStatement = sqlStatement.statement();
            if (preparedStatement != null && !preparedStatement.isClosed()) {
                preparedStatement.close();
            }
        }

        if (connection != null && !connection.isClosed()) {
            connection.close();
        }
    }
}
