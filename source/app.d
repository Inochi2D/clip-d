import std.stdio;
import clip;

void main() {
	CLIP clip = CLIP(File("luna.clip", "rb+"));
	clip.parse();
	writeln(clip.getStats().toString());
	clip.writeChunksToFiles();
}
