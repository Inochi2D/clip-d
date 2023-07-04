module clip.parser;
import clip;
import clip.db;
import clip.utils.io;
import std.bitmanip;
import std.conv;
import std.exception;
static import std.file;
import std.math.rounding;
import std.utf : toUTF8;
import std.typecons;
import std.zlib;

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

struct Rect {
    int x;
    int y;
    int width;
    int height;
};

/**
    Verifies the initial magic bytes of the file
*/
bool verifyMagicBytes(File file) {
    file.seek(0, SEEK_SET);
    return cast(string)file.read(CLIP_MAGIC.length) == CLIP_MAGIC;
}

void parseChunks(ref File file, ref CLIP clip) {
    enforce(file.verifyMagicBytes(), "Invalid magic bytes!");
    clip.fileSize = file.readValue!ulong();
    clip.fileStartOffset = file.readValue!ulong();

    while(true) {
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

            case HEADER_FOOT:
                writeln(clip.extaSections);
                return;

            default:
                enforce(false, "Invalid chunk");
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

void walkLayersInFolder(ref File file, ref CLIP clip, long childIndex) {
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
            walkLayersInFolder(file, clip, layer["LayerFirstChildIndex"].get!(long));
        } else {
            auto mipmapId = layer["LayerRenderMipmap"].get!(long);
            ubyte[] rgba = renderLayer(file, clip, mipmapId);
            std.file.write("layer"~to!string(childIndex)~".data", rgba);
        }

        childIndex = layer["LayerNextIndex"].get!(long);
    }
}

void copy(ref ubyte[] dest, Rect destrect, ubyte[] src, Rect insertrect) {
    foreach (y; 0..insertrect.height) {
        if (y + insertrect.y < destrect.y || y + insertrect.y >= destrect.y + destrect.height) {
            continue;
        }

        foreach (x; 0..insertrect.width) {
            if (x + insertrect.x < destrect.x || x + insertrect.x >= destrect.x + destrect.width) {
                break;
            }

            size_t truex = insertrect.x - destrect.x + x;
            size_t truey = insertrect.y - destrect.y + y;
            size_t desti = truey * destrect.width + truex;
            size_t srci = y * insertrect.width + x;

            dest[desti * 4 + 0] = src[srci * 4 + 0];
            dest[desti * 4 + 1] = src[srci * 4 + 1];
            dest[desti * 4 + 2] = src[srci * 4 + 2];
            dest[desti * 4 + 3] = src[srci * 4 + 3];
        }
    }
}

ubyte[] renderLayer(ref File file, ref CLIP clip, long mipmapIndex) {
    auto mipmap = clip.db.getOne("Mipmap", "MainId", mipmapIndex);
    auto mipmapInfo = clip.db.getOne("MipmapInfo", "MainId", mipmap["BaseMipmapInfo"].get!(long));
    auto offscreen = clip.db.getOne("Offscreen", "MainId", mipmapInfo["Offscreen"].get!(long));

    Attribute attrib = parseAttribute(offscreen["Attribute"].get!(ubyte[]));

    writeln(attrib);

    string externalId = cast(string)offscreen["BlockData"].get!(ubyte[]);
    Nullable!CLIPExtaSection sectionInfo = clip.getExternalById(externalId);
    if (sectionInfo.isNull) {
        return null;
    }

    CLIPExtaData data = parseExtaSection(file, clip, sectionInfo.get);

    writeln("chnk start:", sectionInfo.get.sectionStart);

    uint width = attrib.parameters[0];
    uint height = attrib.parameters[1];
    uint tileW = attrib.parameters[2];
    uint tileH = attrib.parameters[3];
    uint format1 = attrib.parameters[5];
    uint format2 = attrib.parameters[6];

    ubyte[] rgba = new ubyte[width * height * 4];
    Rect rgbaRect = Rect(0, 0, width, height);

    foreach (tiley; 0..tileH) {
        foreach (tilex; 0..tileW) {
            uint tileindex = tiley * tileW + tilex;
            ubyte[] compressedtiledata = data.data[tileindex];

            if (compressedtiledata.length == 0) {
                continue;
            }

            ubyte[] rawtiledata = cast(ubyte[])uncompress(compressedtiledata);
            ubyte[] tile = new ubyte[256 * 256 * 4];
            Rect tileRect = Rect(tilex * 256, tiley * 256, 256, 256);

            if (format1 == 1 && format2 == 4) {
                foreach (i; 0..256*256) {
                    tile[i * 4 + 0] = rawtiledata[65536 + i * 4 + 2];
                    tile[i * 4 + 1] = rawtiledata[65536 + i * 4 + 1];
                    tile[i * 4 + 2] = rawtiledata[65536 + i * 4 + 0];
                    tile[i * 4 + 3] = rawtiledata[i];
                }
                copy(rgba, rgbaRect, tile, tileRect);
            } else {
                writeln("currently unsupported format for layer");
            }
        }
    }

    return rgba;
}

CLIPExtaData parseExtaSection(ref File file, ref CLIP clip, CLIPExtaSection sectionInfo) {
    CLIPExtaData result;

    const size_t endOffset = sectionInfo.sectionStart + sectionInfo.sectionLength;

    uint expectedIndex = 0;

    file.seek(sectionInfo.sectionStart);
    while (file.tell() < endOffset) {
        uint chunkLen = file.readValue!uint();

        if (chunkLen < 38) {
            file.skip(-4);
            enforce(file.cursedReadUTF16() == CHUNK_STATUS);
            file.skip(4);
            uint skip11 = file.readValue!uint();
            uint skip12 = file.readValue!uint();
            file.skip(skip11 * skip12);
            enforce(file.cursedReadUTF16() == CHUNK_CHECK);
            file.skip(4);
            uint skip21 = file.readValue!uint();
            uint skip22 = file.readValue!uint();
            file.skip(skip21 * skip22);
        } else {
            enforce(file.cursedReadUTF16() == CHUNK_BEGIN);

            uint index = file.readValue!uint();
            enforce(index == expectedIndex);
            expectedIndex++;

            file.skip(12);
            if (file.readValue!uint() == 1) {
                uint datasize = file.readValue!uint();
                uint datasize2 = file.readValueLittleEndian!uint();
                assert(datasize == datasize2 + 4);
                ubyte[] data = file.read(datasize2);
                result.data ~= data;
            } else {
                ubyte[] data = new ubyte[0];
                result.data ~= data;
            }
            enforce(file.cursedReadUTF16() == CHUNK_END);
        }
    }
    enforce(file.tell() == endOffset);

    return result;
}

struct Attribute {
    uint[] parameters;
    uint[] colors;
}

Attribute parseAttribute(ubyte[] raw) {
    Attribute result;
    int readIndex = 0;

    uint read() {
        enforce(readIndex + uint.sizeof <= raw.length);

        uint result = bigEndianToNative!uint(raw[readIndex..$][0..uint.sizeof]);
        readIndex += uint.sizeof;
        return result;
    }

    string readStr() {
        uint length = read();
        enforce(readIndex + length * 2 <= raw.length);

        char[] result;
        // TODO: proper BE UTF8 decoding
        foreach (ix; 0..length) {
            result ~= raw[readIndex + 1];
            readIndex += 2;
        }
        return cast(string)result;
    }

    uint headerLength = read();
    enforce(headerLength == 16);

    uint paramsLength = read();
    uint colorsLength = read();
    uint trailLength = read();
    enforce(headerLength + paramsLength + colorsLength + trailLength == raw.length);

    enforce(readStr() == "Parameter");
    while (readIndex < headerLength + paramsLength) {
        result.parameters ~= read();
    }
    enforce(readIndex == headerLength + paramsLength);

    enforce(readStr() == "InitColor");
    while (readIndex < headerLength + paramsLength + colorsLength) {
        result.colors ~= read();
    }
    enforce(readIndex == headerLength + paramsLength + colorsLength);

    return result;
}
