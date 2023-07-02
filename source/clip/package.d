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
    CLIPExtaBlock[] blocks;
}

/**
    A CLIP Exta block
*/
struct CLIPExtaBlock {
    size_t dataStart;
    size_t dataLength;

    union {
        CLIPExtaBlockData blockData;
        ubyte[] statusOrChecksum;
    }
}

/**
    Information about a CLIP Exta block with data 
*/
struct CLIPExtaBlockData {
    uint blockIndex;
    uint flags;

    size_t cDataStart;
    size_t cDataLength;
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

    void writeChunksToFiles() {
        import std.file : write, mkdirRecurse, exists;
        import std.path : buildPath;
        if (!exists("TEST")) mkdirRecurse("TEST");


        foreach(section; extaSections) {
            string extaPath = buildPath("TEST", section.id);
            if (!exists(extaPath)) mkdirRecurse(extaPath);

            import std.stdio : writefln;
            foreach(i, block; section.blocks) {
                writefln("Decompressing %s... (%s..%s)", section.id, section.sectionStart, section.sectionLength);
                write(buildPath(extaPath, "%s.bin".format(block.blockData.blockIndex)), decompressExtaBlock(file, block.blockData));
            }
        }
    }
}