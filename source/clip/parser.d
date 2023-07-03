module clip.parser;
import clip;
import clip.db;
import clip.utils.io;
import std.exception;
import std.math.rounding;
import std.utf : toUTF8;
import std.typecons;

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

Tuple!(long, long) getCanvasDimensions(Row canvas) {
    auto cw = canvas["CanvasWidth"].get!(double);
    auto ch = canvas["CanvasHeight"].get!(double);
    auto res = canvas["CanvasResolution"].get!(double);
    auto unit = canvas["CanvasUnit"].get!(long);

    long w, h;

    switch (unit) {
    case 0:
        w = lround(cw);
        h = lround(ch);
        break;
    case 1:
        w = lround(cw * res / 2.54);
        h = lround(ch * res / 2.54);
        break;
    case 2:
        w = lround(cw * res / 25.4);
        h = lround(ch * res / 25.4);
        break;
    case 3:
        w = lround(cw * res);
        h = lround(ch * res);
        break;
    case 4:
        w = lround(cw * res / 96);
        h = lround(ch * res / 96);
        break;
    case 5:
        w = lround(cw * res / 72);
        h = lround(ch * res / 72);
        break;
    default:
        enforce(false, "Unexpected unit");
    }

    return tuple(w, h);
}

void walkLayersInFolder(ref CLIP clip, long childIndex) {
    while (childIndex != 0) {
        auto layer = clip.db.getOne("Layer", "MainId", childIndex);
        auto layertype = layer["LayerType"].get!(long);
        auto isfolder = layer["LayerFolder"].get!(long); // 0 = no, 1 = open, 17 = closed

        writeln("layer type: ", layertype);
        writeln("layer folder: ", isfolder);
        writeln("layer name: ", layer["LayerName"]);
        writeln("opacity: ", layer["LayerOpacity"]);
        writeln("visibility: ", layer["LayerVisibility"]);
        writeln("blendmode: ", layer["LayerComposite"]);
        writeln("clipping: ", layer["LayerClip"]);
        auto layerMaskMipmapId = layer["LayerLayerMaskMipmap"].get!(long);
        if (!layerMaskMipmapId) {
            // TODO: Parse mask data
        }

        if (isfolder != 0) {
            walkLayersInFolder(clip, layer["LayerFirstChildIndex"].get!(long));
        }

        childIndex = layer["LayerNextIndex"].get!(long);
    }
}
