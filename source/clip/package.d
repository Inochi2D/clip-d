module clip;
import clip.db;
import clip.parser;
import std.algorithm.searching;
import std.exception;
import std.format;
import std.stdio;
import std.typecons;

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

struct CLIPExtaData {
    ubyte[][] data;
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

    CLIPDatabase db;

    Nullable!CLIPExtaSection getExternalById(string id) {
        CLIPExtaSection[] result = extaSections.find!((x) => x.id == id)();
        return result.length > 0 ? nullable(result[0]) : Nullable!CLIPExtaSection.init;
    }

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
        parseChunks(file, this);

        db = new CLIPDatabase(this);

        auto canvas = db.getOne("Canvas");

        writeln(getCanvasDimensions(canvas));

        auto rootFolderIndex = canvas["CanvasRootFolder"].get!(long);
        writeln(rootFolderIndex);
        auto rootFolder = db.getOne("Layer", "MainId", rootFolderIndex);
        writeln(rootFolder);
        auto firstChildIndex = rootFolder["LayerFirstChildIndex"].get!(long);
        walkLayersInFolder(file, this, firstChildIndex);
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
