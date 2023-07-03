module clip.parser;
import clip;
import clip.utils.io;
import std.exception;
import std.utf : toUTF8;

/// CLIP Magic Bytes
enum CLIP_MAGIC = "CSFCHUNK";

/// CLIP Header
enum HEADER_HEAD = "CHNKHead";

/// CLIP ExtA Data, Layers and such
enum HEADER_EXTA = "CHNKExta";

/// CLIP SQLite3 Database
enum HEADER_SQLI = "CHNKSQLi";

/// CLIP Footer :)
enum HEADER_FOOT = "CHNKFoot";

/// Beginning of an Exta Chunk
enum CHUNK_BEGIN = "BlockDataBeginChunk";

/// End of an Exta Chunk
enum CHUNK_END = "BlockDataEndChunk";

/// Status of an Exta Chunk
enum CHUNK_STATUS = "BlockStatus";

/// Checksum of an Exta Chunk
enum CHUNK_CHECK = "BlockCheckSum";

/**
    Verifies the initial magic bytes of the file
*/
bool verifyMagicBytes(File file) {
    file.seek(0, SEEK_SET);
    return cast(string)file.read(CLIP_MAGIC.length) == CLIP_MAGIC;
}

void beginParse(ref File file, ref CLIP clip) {
    enforce(file.verifyMagicBytes(), "Invalid magic bytes!");
    clip.fileSize = file.readValue!ulong();
    clip.fileStartOffset = file.readValue!ulong();

    mloop: while(true) {
        string hdr = cast(string)file.read(8);
        ulong length = file.readValue!ulong();
        ulong start = file.tell();


        switch(hdr) {
            case HEADER_HEAD:
                clip.headSections ~= CLIPSection(start, length);
                file.skip(length);
                break;
            case HEADER_EXTA:
                
                // Exta has extra data, as such we need to shuffle
                // some things around.
                ulong strlength = file.readValue!ulong();
                string id = cast(string)file.read(strlength);
                ulong datalength = file.readValue!ulong();
                ulong rstart = file.tell();

                // Then we can add it.
                clip.extaSections ~= CLIPExtaSection(rstart, datalength, id);
                file.seek(rstart+datalength);
                break;
            case HEADER_SQLI:
                clip.sqliteSections ~= CLIPSection(start, length);
                file.skip(length);
                break;

            default: break mloop;
        }
    }
}