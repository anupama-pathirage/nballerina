public function main() {
    int x = 1;
    if x == 1 {
    }
    else if x == 1 {  // this should get an error because x should be narrowed to not include `1` so the operand types are disjoint
    }
}
