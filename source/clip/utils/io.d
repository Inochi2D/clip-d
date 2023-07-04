module clip.utils.io;
import std.bitmanip;
import std.string;

public import std.file;
public import std.stdio;

/**
    Reads file value in big endian fashion
*/
T readValue(T)(ref File file) {
    T value = bigEndianToNative!T(file.rawRead(new ubyte[T.sizeof])[0 .. T.sizeof]);
    return value;
}

/**
    Reads file value in little endian fashion
*/
T readValueLittleEndian(T)(ref File file) {
    T value = littleEndianToNative!T(file.rawRead(new ubyte[T.sizeof])[0 .. T.sizeof]);
    return value;
}

/**
    Reads values
*/
ubyte[] read(ref File file, size_t length) {
    return file.rawRead(new ubyte[length]);
}

/**
    Reads values
*/
ubyte[] readAt(ref File file, size_t offset, size_t length) {
    file.seek(offset, SEEK_SET);
    return file.rawRead(new ubyte[length]);
}

/**
    Peeks values
*/
ubyte[] peek(ref File file, ptrdiff_t length) {
    ubyte[] result = file.read(length);
    file.seek(-cast(ptrdiff_t)length, SEEK_CUR);
    return result;
}

/**
    Skips bytes
*/
void skip(ref File file, ptrdiff_t length) {
    file.seek(cast(ptrdiff_t)length, SEEK_CUR);
}

/**
    Cursed reading function
*/
string cursedReadUTF16(ref File file) {
    uint length = file.readValue!uint();

    // This is beyond cursed, the UTF16 format here is doing funky stuff
    // this is ugly *but it works*
    string fBlockType = cast(string)file.read(length*2);
    char[] oblockType;
    foreach(ix; 0..(fBlockType.length/2)) {
        oblockType ~= fBlockType[1+(ix*2)];
    }

    return cast(string)oblockType.dup;
}
