module clip.db;
import clip;
import clip.utils.io;
import etc.c.sqlite3;
import std.conv;
import std.exception;
import std.string;
import std.variant;

struct Null {}
alias Column = Algebraic!(long, double, string, ubyte[], Null);
alias Row = Column[string];
alias QueryResult = Row[];

class CLIPDatabase {
private:
    sqlite3* handle;
    ubyte[] rawDatabase;

    QueryResult consumeStatement(sqlite3_stmt* stmt) {
        int result;
        QueryResult qr;

        for (result = sqlite3_step(stmt); result == SQLITE_ROW; result = sqlite3_step(stmt)) {
            Row row = new Row;
            const int numCols = sqlite3_column_count(stmt);
            for (int i = 0; i < numCols; i++) {
                string colName = to!string(sqlite3_column_name(stmt, i));
                switch (sqlite3_column_type(stmt, i)) {
                case SQLITE_INTEGER:
                    row[colName] = sqlite3_column_int64(stmt, i);
                    break;
                case SQLITE_FLOAT:
                    row[colName] = sqlite3_column_double(stmt, i);
                    break;
                case SQLITE3_TEXT:
                    row[colName] = to!string(sqlite3_column_text(stmt, i));
                    break;
                case SQLITE_BLOB:
                    const(void)* rawdata = sqlite3_column_blob(stmt, i);
                    size_t len = sqlite3_column_bytes(stmt, i);
                    ubyte[] data = new ubyte[len];
                    data[0 .. len][] = (cast(const(ubyte)*)rawdata)[0 .. len];
                    row[colName] = data;
                    break;
                case SQLITE_NULL:
                    row[colName] = Null();
                    break;
                default:
                    assert(false, "Unexpected column type");
                }
            }
            qr ~= row;
        }
        enforce(result == SQLITE_DONE);

        result = sqlite3_finalize(stmt);
        enforce(result == SQLITE_OK);

        return qr;
    }

public:
    this(ref CLIP clip) {
        enforce(clip.sqliteSections.length == 1);

        rawDatabase = clip.file.readAt(clip.sqliteSections[0].sectionStart, clip.sqliteSections[0].sectionLength);

        int result;

        result = sqlite3_open_v2("file:/memory?vfs=memdb", &handle, SQLITE_OPEN_READONLY, null);
        enforce(result == SQLITE_OK);

        result = sqlite3_deserialize(handle, "main".toStringz(), cast(ubyte*)rawDatabase, rawDatabase.length, rawDatabase.length, SQLITE_DESERIALIZE_READONLY);
        enforce(result == SQLITE_OK);
    }

    QueryResult get(string tableName) {
        int result;

        string sql = "SELECT * FROM " ~ tableName ~ "\0";

        sqlite3_stmt *stmt;
        result = sqlite3_prepare_v2(handle, cast(char*)sql, cast(int)sql.length, &stmt, null);
        enforce(result == SQLITE_OK);

        return consumeStatement(stmt);
    }

    Row getOne(string tableName) {
        QueryResult qr = get(tableName);
        enforce(qr.length == 1);
        return qr[0];
    }

    QueryResult get(string tableName, string colName, long expectedValue) {
        int result;

        string sql = "SELECT * FROM " ~ tableName ~ " WHERE " ~ colName ~ " = ?\0";

        sqlite3_stmt *stmt;
        result = sqlite3_prepare_v2(handle, cast(char*)sql, cast(int)sql.length, &stmt, null);
        enforce(result == SQLITE_OK);

        result = sqlite3_bind_int64(stmt, 1, expectedValue);
        enforce(result == SQLITE_OK);

        return consumeStatement(stmt);
    }

    Row getOne(string tableName, string colName, long expectedValue) {
        QueryResult qr = get(tableName, colName, expectedValue);
        enforce(qr.length == 1);
        return qr[0];
    }

    ~this() {

    }
}
