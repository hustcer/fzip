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

///|
test "huffman array pool reuse" {
  let initial_pool_len = h_tree_s_pool.length()
  let freq1 : FixedArray[Int] = FixedArray::make(4, 0)
  freq1[0] = 5
  freq1[1] = 3
  freq1[2] = 1
  freq1[3] = 1
  let _ = h_tree(freq1, 15)
  let pool_len_1 = h_tree_s_pool.length()
  assert_true(pool_len_1 > initial_pool_len || pool_len_1 == initial_pool_len)

  let freq2 : FixedArray[Int] = FixedArray::make(5, 0)
  freq2[0] = 10
  freq2[1] = 2
  freq2[2] = 2
  freq2[3] = 1
  freq2[4] = 1
  let _ = h_tree(freq2, 15)
  let pool_len_2 = h_tree_s_pool.length()
  // Pool length should remain stable as arrays are reused
  assert_true(pool_len_2 == pool_len_1)
}

///|
test "huffman pool correctness - multiple trees" {
  // Verify that pool reuse produces correct code lengths
  let freq1 : FixedArray[Int] = FixedArray::make(6, 0)
  freq1[0] = 10
  freq1[1] = 5
  freq1[2] = 3
  freq1[3] = 2
  freq1[4] = 1
  freq1[5] = 1
  let (codes1, max_bits1) = h_tree(freq1, 15)
  assert_true(max_bits1 > 0 && max_bits1 <= 15)
  assert_eq(codes1.length(), 6)

  let freq2 : FixedArray[Int] = FixedArray::make(8, 0)
  freq2[0] = 20
  freq2[1] = 15
  freq2[2] = 10
  freq2[3] = 8
  freq2[4] = 5
  freq2[5] = 3
  freq2[6] = 2
  freq2[7] = 1
  let (codes2, max_bits2) = h_tree(freq2, 15)
  assert_true(max_bits2 > 0 && max_bits2 <= 15)
  assert_eq(codes2.length(), 8)

  // Verify first tree result is still valid by rebuilding
  let (codes1_again, max_bits1_again) = h_tree(freq1, 15)
  assert_eq(max_bits1, max_bits1_again)
  assert_eq(codes1.length(), codes1_again.length())
  for i in 0..<codes1.length() {
    assert_eq(codes1[i], codes1_again[i])
  }
}
