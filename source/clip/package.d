module clip;
import std.stdio : File;
import std.format;
import clip.parser;

/**
    A CLIP section
*/
struct CLIPSection {
    size_t sectionStart;
    size_t sectionLength;
}

/**
    A CLIP Exta chunk section
*/
struct CLIPExtaSection {
    size_t sectionStart;
    size_t sectionLength;
    string id;
}

struct CLIPStats {
    int headSections;
    int extaSections;
    int sqliteDatabases;

    string toString() const {
        return "{ \"headers\": %s, \"extas\": %s, \"dbs\": %s }".format(
            headSections,
            extaSections,
            sqliteDatabases
        );
    }
}

struct CLIP {
package(clip):
    File file;

    size_t fileSize;
    size_t fileStartOffset;

    CLIPSection[] headSections;
    CLIPExtaSection[] extaSections;
    CLIPSection[] sqliteSections;

    size_t footerOffset;

public:

    /**
        Creates a CLIP instance for the specified file
    */
    this(File file) {
        this.file = file;
    }
    
    /**
        Creates a CLIP instance for the specified file path
    */
    this(string file) {
        this.file = File(file, "rb+");
    }

    /**
        Closes the clip file.
    */
    void close() {
        file.close();
    }

    /**
        Parses the file
    */
    void parse() {
        beginParse(file, this);
    }

    /**
        Gets the data of the file
    */
    CLIPStats getStats() {
        return CLIPStats(
            cast(int)headSections.length,
            cast(int)extaSections.length,
            cast(int)sqliteSections.length
        );
    }
}