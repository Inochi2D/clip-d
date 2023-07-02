# The CLIP Specification
CLIP is a file format for CLIP STUDIO PAINT, a peice of drawing software by CELSYS.
This information has been clean-room reverse engineered through inspecting output files,  
from the software.

The CLIP format encodes numeric values in big endian format.

## Chunks
A CLIP file is split up in to multiple chunks, each chunk being 8 bytes long.

A file always starts with the `CSFCHUNK` chunk, followed by 8 bytes of file length, then 8 bytes of offset info in big endian format.

After which there is a `CHNKHead` chunk, which contains header information for the CLIP file.

After which there may be 1 or more `CHNKExta` chunks, followed by a `CHNKSQLi` chunk and a `CHNKFoot` footer.

## CHNKHead

Don't know yet

## CHNKExta

CHNKExta the image data and layer data, it is compressed via zlib.

