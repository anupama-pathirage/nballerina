import ballerina/io;

public function main() {
    // Type of !true is a singleton, so operand types are disjoint.
    io:println(true == !true); // @error
}