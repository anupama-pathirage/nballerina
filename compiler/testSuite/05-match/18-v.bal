import ballerina/io;

public function main() {
    foo("foo"); // @output foo!
}

public function foo(any x) {
    match x {
        "foo"|true|42 => {
            if x == "foo" {
                io:println("foo!");
            }
        }
    }
}
