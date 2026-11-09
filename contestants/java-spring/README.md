# java-spring
Spring Boot web (embedded Tomcat) with JdbcTemplate and the xerial sqlite-jdbc driver, HikariCP's default pool, `java -jar` with the JVM's default heap (a quarter of RAM). OpenJDK 21 and Maven from Ubuntu. The POST handler takes the raw body as a String because the spec wants the token checked before the JSON is parsed. No tuning.
