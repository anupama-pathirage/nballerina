import ballerina/io;

public function main() {
    foo(1);
}

function foo(any v) {
    match v {
        _ => { 
            io:println("any");
        }
        1 => { // @error
            io:println("one");
        }
    }
}