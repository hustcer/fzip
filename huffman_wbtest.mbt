///|
test "freb - generates base values" {
  // fl[0] should be 3 (first match length)
  inspect(fl[0], content="3")
  // fl[28] should be 258
  inspect(fl[28], content="258")
  // revfl[258] should be 28
  inspect(revfl[258], content="28")
}

///|
test "h_map - fixed length tree" {
  // flm should be non-empty
  assert_true(flm.length() > 0)
  // flrm should be non-empty
  assert_true(flrm.length() > 0)
  // fdm should be non-empty
  assert_true(fdm.length() > 0)
  // fdrm should be non-empty
  assert_true(fdrm.length() > 0)
}

///|
test "h_tree - simple frequency table" {
  let freq : FixedArray[Int] = FixedArray::make(4, 0)
  freq[0] = 5
  freq[1] = 3
  freq[2] = 1
  freq[3] = 1
  let (tree, max_bits) = h_tree(freq, 15)
  // All symbols should have non-zero code lengths
  assert_true(tree[0].to_int() > 0)
  assert_true(tree[1].to_int() > 0)
  assert_true(tree[2].to_int() > 0)
  assert_true(tree[3].to_int() > 0)
  assert_true(max_bits > 0)
  assert_true(max_bits <= 15)
}

///|
test "lc_gen - basic code generation" {
  let codes : FixedArray[Byte] = [b'\x02', b'\x03', b'\x03', b'\x02']
  let (cl, n) = lc_gen(codes)
  assert_true(cl.length() > 0)
  assert_true(n > 0)
}

///|
test "rev - bit reversal table" {
  // rev[0] should be 0
  inspect(rev[0], content="0")
  // rev[1] should be 16384 (1 reversed in 15 bits)
  inspect(rev[1], content="16384")
}
