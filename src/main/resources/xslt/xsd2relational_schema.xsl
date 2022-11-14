<?xml version="1.0"?>

<!-- XSL Transformation: XSD -> Generic relational database schema -->

<xsl:stylesheet version="2.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:xs="http://www.w3.org/2001/XMLSchema"
	xmlns:local="http://localhost/xsl/definitions"
	exclude-result-prefixes="local">
	<xsl:output method="xml" encoding="UTF-8" indent="yes" omit-xml-declaration="no" />

	<!-- Select schema nodes from this schema and any included schemas -->
	<xsl:variable 
		name="contents"
		select="/|document(//xs:include/@schemaLocation)" />

	<!-- Select all named complex types -->
	<xsl:variable 
		name="complexTypes"
		select="$contents//xs:complexType[@name]" />
	
	<!-- Target namespace -->
	<xsl:variable name="local:targetNamespace" select="/xs:schema/@targetNamespace"/>
			
	<xsl:template match="/">
		
		<!-- Target root element -->
		<xsl:element name="relational_schema" namespace="{$local:targetNamespace}">
			
			<!-- Match target table elements -->
			<xsl:for-each select="$contents">
				<xsl:apply-templates select=".//xs:element" />
			</xsl:for-each>
			
		</xsl:element>
		
	</xsl:template>

	<!-- Target table element -->
	<xsl:template match="xs:element">
		
		<xsl:comment>
			<xsl:value-of select="self::node()/@name"/>
		</xsl:comment>

		<!-- Get the complex type that defines it, if any -->
		<xsl:variable 
			name="complexType"
			select="xs:complexType[not(@name)]
					|$complexTypes[@name=current()/@type]" />

		<xsl:if test="$complexType">

			<!-- Target table must have at least one field -->

			<xsl:variable 
				name="fields"
				select="$complexType/xs:sequence/xs:element[not(@type=$complexTypes/@name) and (@type or xs:simpleType/xs:restriction/@base)]
						|$complexType/xs:attribute
						|$complexType/xs:simpleContent
						|$complexType/xs:simpleContent/xs:extension/xs:attribute
						|$complexType/xs:sequence/xs:choice/xs:element[not(@type=$complexTypes/@name)]" />
			
				<!--
				select="$complexType/xs:sequence/xs:element[not(@type=$complexTypes/@name) and (@type or xs:simpleType/xs:restriction/@base)]
						  |$complexType/xs:attribute
						  |$complexType/xs:simpleContent
						  |$complexType/xs:simpleContent/xs:extension/xs:attribute
						  |$complexType/xs:sequence/xs:choice/xs:element[not(@type=$complexTypes/@name)]" />
				-->
			<xsl:if test="$fields">

				<!-- Table name -->
				<xsl:variable name="tableName" select="@name" />

				<!-- Generated primary key name. We may not use this, depending on whether 
					a primary key is declared in the xsd. -->

				<xsl:variable name="generatedKey"
					select="concat($tableName, '_id')" />

				<!-- Get primary key declaration, if any, and use that to determine whether 
					to create an Id field -->

				<!--<xsl:variable name="primaryKey"
					select="//xs:key[@msdata:PrimaryKey='true'][xs:selector[@xpath=concat('.//mstns:',$tableName)]]" />-->

				<!-- Insert ID field -->
				<!--<xsl:if test="not($primaryKey)">

				</xsl:if>-->
				
				<xsl:element name="table" namespace="{$local:targetNamespace}">
					<xsl:attribute name="name">
						<xsl:value-of select="$tableName"/>
					</xsl:attribute>
					<!--<xsl:attribute name="comment">
						<xsl:value-of select="xs:annotation/xs:documentation"/>
					</xsl:attribute>-->
					<xsl:attribute name="parent">
						<xsl:value-of select="string-join(ancestor::xs:element[@name]/@name, '/')"/>
					</xsl:attribute>

					<xsl:variable 
						name="ancestorTables" 
						select="ancestor::xs:element[@name][xs:complexType[xs:sequence[xs:element[@type]] or xs:attribute[@type] or xs:simpleContent]]" />
								<!-- $contents//xs:element[@type=current()/ancestor::*/@name]" -->
								
						
					<!-- Target table columns -->
					<xsl:for-each select="$fields">
					<!--<xsl:for-each select="$fields[not(@type=$complexTypes/@name)]">-->
					
						<xsl:comment>
							<xsl:value-of select="string-join(ancestor::*/name(), '/')"/>
						</xsl:comment>
											
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
								<!--<xsl:attribute name="comment"><xsl:value-of select="xs:annotation/xs:documentation"/></xsl:attribute>-->
								
								<xsl:attribute name="type">
									<xsl:value-of select="@type|xs:simpleType/xs:restriction/@base|xs:simpleContent/xs:extension/@base"/>
								</xsl:attribute>
								<!-- Optional elements become nullable columns -->
								<xsl:if test="@minOccurs=0">
									<xsl:attribute name="nullable">
										<xsl:value-of select="true()"/>
									</xsl:attribute>
								</xsl:if>								
								<!-- maxLength restriction -->
								<xsl:call-template name="optional-attribute">
									<xsl:with-param name="attrName" select="'maxLength'" />
									<xsl:with-param name="attrValue" select="(xs:simpleType/xs:restriction/xs:maxLength/@value, xs:simpleContent/xs:extension/xs:maxLength/@value)[1]" />
								</xsl:call-template>			
								<!-- totalDigits restriction -->
								<xsl:call-template name="optional-attribute">
									<xsl:with-param name="attrName" select="'totalDigits'" />
									<xsl:with-param name="attrValue" select="(xs:simpleType/xs:restriction/xs:totalDigits/@value, xs:simpleContent/xs:extension/xs:totalDigits/@value)[1]" />
								</xsl:call-template>			
								<!-- fractionDigits restriction -->								
								<xsl:call-template name="optional-attribute">
									<xsl:with-param name="attrName" select="'fractionDigits'" />
									<xsl:with-param name="attrValue" select="(xs:simpleType/xs:restriction/xs:fractionDigits/@value, xs:simpleContent/xs:extension/xs:fractionDigits/@value)[1]" />
								</xsl:call-template>			
							</xsl:element>
						</xsl:if>
													
					</xsl:for-each>
					
				</xsl:element>
				
			</xsl:if>
			
		</xsl:if>

<!--		<xsl:apply-templates />-->
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