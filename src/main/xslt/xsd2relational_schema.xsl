<?xml version="1.0"?>

<!-- XSL Transformation: XSD -> Generic relational database schema -->

<xsl:stylesheet version="2.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:xs="http://www.w3.org/2001/XMLSchema"
	xmlns:local="http://localhost/xsl/definitions"
	exclude-result-prefixes="local">
	<xsl:output method="xml" encoding="UTF-8" indent="yes" omit-xml-declaration="no"/>

	<!-- Select schema nodes from this schema and any included schemas -->
	<xsl:variable 
		name="contents"
		select="/|document(//xs:include/@schemaLocation)" />

	<!-- Select all named complex types -->
	<xsl:variable 
		name="complexTypes"
		select="$contents//xs:complexType[@name]" />

	<!-- Select all named simple types -->
	<xsl:variable
		name="simpleTypes"
		select="$contents//xs:simpleType[@name]" />

	<!-- Target namespace -->
	<xsl:variable name="local:targetNamespace" select="/xs:schema/@targetNamespace"/>
			
	<xsl:template match="/">

		<!-- Target root element -->
		<xsl:element name="relational_schema" namespace="{$local:targetNamespace}">

			<!-- Newline and tab before the first comment -->
			<xsl:text>&#xA;&#x9;</xsl:text>

			<!-- Match target table elements -->
			<xsl:apply-templates select="$contents/xs:schema/xs:element"/>

		</xsl:element>

	</xsl:template>

	<!-- Target table element -->
	<xsl:template match="xs:element">
		
		<xsl:param name="masterEntity"/>
		<xsl:param name="masterTable"/>
		
		<xsl:comment>
			<xsl:value-of select="@name"/>
		</xsl:comment>

		<!-- Get the complex type that defines it, if any -->
		<xsl:variable 
			name="complexType"
			select="xs:complexType[not(@name)]
					|$complexTypes[@name=current()/@type]" />

		<xsl:if test="$complexType">

			<!-- Target table must have at least one field -->
			<xsl:variable 
				name="entityNodes"
				select="$complexType/xs:sequence/xs:element
						|$complexType/xs:attribute
						|$complexType/xs:simpleContent
						|$complexType/xs:simpleContent/xs:extension/xs:attribute
						|$complexType/xs:sequence/xs:choice/xs:element" />
				
			<xsl:if test="$entityNodes">		
				
				<!-- Table name -->
				<xsl:variable name="tableName" select="@name" />
				<xsl:variable name="entityPath" select="concat($masterEntity, '/', $tableName)" />
					
				<xsl:variable 
					name="identifiers"
					select="$entityNodes[matches(@name, 'id$|^id', 'i') and (@minOccurs=1 or @use='required')]/@name" />
	
				<xsl:variable 
					name="identifier"
					select="$entityNodes[matches(@name, '^id$', 'i') and (@minOccurs=1 or @use='required')]/@name" />
						
				<xsl:variable name="primaryKey">
					<xsl:choose>
						<xsl:when test="$identifier"> 
							<xsl:value-of select="$identifier" />
						</xsl:when>
						<xsl:when test="count($identifiers) = 1">
							<xsl:value-of select="$identifiers" />
						</xsl:when>
					</xsl:choose>
				</xsl:variable>					

				<xsl:variable 
					name="fields"
					select="$entityNodes[not(@type=$complexTypes/@name) and not(xs:complexType)]" />
																		
				<xsl:if test="$fields">
	
					<xsl:element name="table" namespace="{$local:targetNamespace}">
						<xsl:attribute name="name">
							<xsl:value-of select="$tableName"/>
						</xsl:attribute>
						
						<xsl:attribute name="path">
							<xsl:value-of select="$entityPath"/>
						</xsl:attribute>
												
						<xsl:attribute name="comment">
							<xsl:value-of select="xs:annotation/xs:documentation"/>
						</xsl:attribute>
	
						<xsl:if test="$primaryKey">
							<xsl:attribute name="primaryKey">
								<xsl:value-of select="$primaryKey"/>
							</xsl:attribute>
						</xsl:if>						

						<xsl:if test="$masterTable != ''">
							<xsl:attribute name="masterTable">
								<xsl:value-of select="$masterTable"/>
							</xsl:attribute>
						</xsl:if>						
							
						<!-- Target table columns -->
						<xsl:for-each select="$fields">
						
							<xsl:variable name="columnName">						
								<xsl:choose>
									<xsl:when test="@name">
										<xsl:value-of select="@name" />
									</xsl:when>
									<xsl:when test="local-name()='simpleContent'">
										<xsl:value-of select="concat(parent::*/@name,'_Text')" />
									</xsl:when>
								</xsl:choose>
							</xsl:variable>
							
							<xsl:if test="$columnName">
								<xsl:element name="column" namespace="{$local:targetNamespace}">
									<xsl:attribute name="name">
										<xsl:value-of select="$columnName"/>
									</xsl:attribute>
									<xsl:attribute name="comment"><xsl:value-of select="xs:annotation/xs:documentation"/></xsl:attribute>
									<xsl:attribute name="path">
										<xsl:choose>
											<xsl:when test="local-name()='attribute'">
												<xsl:value-of select="concat('@', $columnName)" />
											</xsl:when>
											<xsl:otherwise>
												<xsl:value-of select="$columnName" />
											</xsl:otherwise>
										</xsl:choose>
									</xsl:attribute>
									<!-- Get user-defined simple type info, if any -->
									<xsl:variable
										name="customSimpleType"
										select="$simpleTypes[@name=current()/@type]" />
									<xsl:choose>
										<xsl:when test="$customSimpleType">
											<xsl:attribute name="type">
												<xsl:value-of select="$customSimpleType/xs:restriction/@base"/>
											</xsl:attribute>
											<xsl:call-template name="value-restrictions">
												<xsl:with-param name="container" select="$customSimpleType" />
											</xsl:call-template>
										</xsl:when>
										<xsl:otherwise>
											<xsl:attribute name="type">
												<xsl:value-of select="@type|xs:simpleType/xs:restriction/@base|xs:simpleContent/xs:extension/@base"/>
											</xsl:attribute>
											<xsl:call-template name="value-restrictions">
												<xsl:with-param name="container" select="current()" />
											</xsl:call-template>
										</xsl:otherwise>
									</xsl:choose>
									<!-- Optional elements become nullable columns -->
									<xsl:choose>
										<xsl:when test="@minOccurs=0 or @use='optional'">
											<xsl:attribute name="nullable">
												<xsl:value-of select="true()"/>
											</xsl:attribute>
										</xsl:when>
										<xsl:when test="@minOccurs=1 or @use='required'">
											<xsl:attribute name="nullable">
												<xsl:value-of select="false()"/>
											</xsl:attribute>
										</xsl:when>
									</xsl:choose>
									<!-- Multivalued attribute -->
									<xsl:choose>
										<xsl:when test="@maxOccurs='unbounded' or @maxOccurs>1">
											<xsl:attribute name="isMultivalued">
												<xsl:value-of select="true()"/>
											</xsl:attribute>
										</xsl:when>
									</xsl:choose>
								</xsl:element>
							</xsl:if>
														
						</xsl:for-each>
						
					</xsl:element>
					
				</xsl:if>

				<xsl:variable name="createdTable">
					<xsl:choose>
						<xsl:when test="$fields">
							<xsl:value-of select="$entityPath"/>
						</xsl:when>
						<xsl:otherwise>
							<xsl:value-of select="$masterTable"/>				
						</xsl:otherwise>
					</xsl:choose>				
				</xsl:variable>
				
				<!-- Nested tables -->
				<xsl:apply-templates select="$entityNodes[@type=$complexTypes/@name or xs:complexType]">
					<xsl:with-param name="masterEntity" select="$entityPath"/>
					<xsl:with-param name="masterTable" select="$createdTable"/>
				</xsl:apply-templates>
								
			</xsl:if>

		</xsl:if>
											
	</xsl:template>

	<!-- Value restrictions -->
	<xsl:template name="value-restrictions">
		<xsl:param name="container"/>

		<xsl:for-each select="(
			'pattern'
			, 'minLength'
			, 'maxLength'
			, 'enumeration'
			, 'totalDigits'
			, 'fractionDigits'
			, 'length'
			, 'maxExclusive'
			, 'maxInclusive'
			, 'minExclusive'
			, 'minInclusive'
			, 'whiteSpace'
		)">
			<xsl:call-template name="select-restriction">
				<xsl:with-param name="restrictionType" select="."/>
				<xsl:with-param name="container" select="$container"/>
			</xsl:call-template>
		</xsl:for-each>
	</xsl:template>

	<!-- Select value restriction -->
	<xsl:template name="select-restriction">
		<xsl:param name="restrictionType"/>
		<xsl:param name="container"/>

		<xsl:call-template name="optional-attribute">
			<xsl:with-param name="attrName" select="$restrictionType" />
			<!-- coalesce logic: pick the first non-empty item -->
			<xsl:with-param name="attrValue" select="(
				$container/xs:restriction/*[local-name() = $restrictionType]/@value
				, $container/xs:simpleType/xs:restriction/*[local-name() = $restrictionType]/@value
				, $container/xs:simpleContent/xs:extension/*[local-name() = $restrictionType]/@value
			)[1]"/>
		</xsl:call-template>
	</xsl:template>

	<!-- Optional attribute -->
	<xsl:template name="optional-attribute">
		<xsl:param name="attrName"/>  
		<xsl:param name="attrValue"/>  
		
		<xsl:if test="$attrValue != ''">
			<xsl:attribute name="{$attrName}">
				<xsl:value-of select="$attrValue"/>
			</xsl:attribute>
		</xsl:if>		
	</xsl:template>
	
</xsl:stylesheet>					