import ballerina/io;

public function main() {
    float[] v = [0.5, 1.5, 2.5];
    io:println(v[0] + v[1] + v[2]); // @output 4.5
}
