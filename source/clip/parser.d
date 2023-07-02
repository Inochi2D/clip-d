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

bool tryParseChunkDataBlock(ref File file, ref CLIPExtaBlock block) {
    size_t start = file.tell();

    uint lengthOfData = file.readValue!uint();
    uint lengthOfName = file.readValue!uint();

    // Not a data block
    if (file.cursedReadUTF8(lengthOfName) != CHUNK_BEGIN) {
        file.seek(start);
        return false;
    }

    enum LENGTH_OF_END = 84;
    enum PADDING = 20;
    block.dataStart = start;
    block.dataLength = lengthOfData;
    block.blockData.blockIndex = file.readValue!uint();
    block.blockData.flags = file.readValue!uint();
    block.blockData.cDataStart = file.tell()+PADDING;
    block.blockData.cDataLength = block.dataLength - (8+LENGTH_OF_END+PADDING);
    file.seek(start+lengthOfData);
    return true;
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
                CLIPExtaBlock[] blocks;
                
                // Exta has extra data, as such we need to shuffle
                // some things around.
                ulong strlength = file.readValue!ulong();
                string id = cast(string)file.read(strlength);
                ulong datalength = file.readValue!ulong();
                ulong rstart = file.tell();
                
                // Read blocks
                ulong i = rstart;
                CLIPExtaBlock block;
                while(tryParseChunkDataBlock(file, block)) {
                    blocks ~= block;
                }

                // Then we can add it.
                clip.extaSections ~= CLIPExtaSection(rstart, datalength, id, blocks);
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

ubyte[] decompressExtaBlock(File file, CLIPExtaBlockData block) {
    import std.zlib;
    file.seek(block.cDataStart, SEEK_SET);
    // return file.read(block.cDataLength); //cast(ubyte[])uncompress();
    return cast(ubyte[])uncompress(file.read(block.cDataLength));
}