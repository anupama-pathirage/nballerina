import ballerina/io;

public function main() {
    io:println(-1.toHexString()); // @error
}
