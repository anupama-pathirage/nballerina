import ballerina/io;

type List (any|error)[];

public function main() {
    List v = [];
    v[0] = 1;
    v[1] = [];
    v[2] = error("whoops");
    io:println(v); // @output [1,[],error("whoops")]
}
