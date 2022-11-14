import net.sf.saxon.s9api.*;
import java.io.*;
import javax.xml.transform.stream.StreamSource;

public class Main {

	public static void main(String[] args) throws FileNotFoundException {
		
		ClassLoader classLoader = Main.class.getClassLoader();
		InputStream xslt = classLoader.getResourceAsStream("xslt/xsd2relational_schema.xsl");
		InputStream xsd = classLoader.getResourceAsStream(args[0]);
		
		try {
			Processor processor = new Processor(false);
			XsltCompiler compiler = processor.newXsltCompiler();
			XsltExecutable stylesheet = compiler.compile(new StreamSource(xslt));
			Serializer out = processor.newSerializer(new File("result.xml"));
			Xslt30Transformer trans = stylesheet.load30();
			trans.transform(new StreamSource(xsd), out);
		} catch (SaxonApiException e) {
			e.printStackTrace();
		}

	}	
	
}
