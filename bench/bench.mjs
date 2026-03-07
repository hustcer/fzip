import { Bench } from 'tinybench';
import {
  deflateSync,
  inflateSync,
  gzipSync,
  gunzipSync,
  zlibSync,
  unzlibSync,
  zipSync,
  unzipSync,
  decompressSync,
} from 'fflate';

// ============================================================
// Data generation (mirrors bench_test.mbt exactly)
// ============================================================

function makeZeros(size) {
  return new Uint8Array(size);
}

function makeSequential(size) {
  const data = new Uint8Array(size);
  for (let i = 0; i < size; i++) {
    data[i] = i % 256;
  }
  return data;
}

function makeRandom(size, seed) {
  const data = new Uint8Array(size);
  let s = seed;
  for (let i = 0; i < size; i++) {
    s = (s * 1103515245 + 12345) & 0x7fffffff;
    data[i] = (s >> 16) & 0xff;
  }
  return data;
}

function makeZipFiles() {
  return {
    'hello.txt': makeSequential(512),
    'data.bin': makeRandom(2048, 42),
    'zeros.dat': makeZeros(1024),
  };
}

// ============================================================
// Bench setup
// ============================================================

const bench = new Bench({ warmupIterations: 100 });

// Pre-generate test data
const zeros1k = makeZeros(1024);
const zeros100k = makeZeros(102400);
const seq1k = makeSequential(1024);
const seq100k = makeSequential(102400);
const random1k = makeRandom(1024, 42);
const random100k = makeRandom(102400, 42);
const zipFiles = makeZipFiles();

// Pre-compress data for decompress benchmarks
const deflSeq1k = deflateSync(seq1k);
const deflSeq100k = deflateSync(seq100k);
const gzipSeq1k = gzipSync(seq1k);
const gzipSeq100k = gzipSync(seq100k);
const zlibSeq1k = zlibSync(seq1k);
const zlibSeq100k = zlibSync(seq100k);
const zippedData = zipSync(zipFiles);

// ============================================================
// DEFLATE compress — 3 patterns × 2 sizes = 6
// ============================================================

bench.add('deflate/compress/zeros_1k/fflate', () => { deflateSync(zeros1k); });
bench.add('deflate/compress/zeros_100k/fflate', () => { deflateSync(zeros100k); });
bench.add('deflate/compress/seq_1k/fflate', () => { deflateSync(seq1k); });
bench.add('deflate/compress/seq_100k/fflate', () => { deflateSync(seq100k); });
bench.add('deflate/compress/random_1k/fflate', () => { deflateSync(random1k); });
bench.add('deflate/compress/random_100k/fflate', () => { deflateSync(random100k); });

// ============================================================
// DEFLATE decompress — 2 sizes = 2
// ============================================================

bench.add('deflate/decompress/1k/fflate', () => { inflateSync(deflSeq1k); });
bench.add('deflate/decompress/100k/fflate', () => { inflateSync(deflSeq100k); });

// ============================================================
// GZIP compress — 2 sizes = 2
// ============================================================

bench.add('gzip/compress/1k/fflate', () => { gzipSync(seq1k); });
bench.add('gzip/compress/100k/fflate', () => { gzipSync(seq100k); });

// ============================================================
// GZIP decompress — 2 sizes = 2
// ============================================================

bench.add('gzip/decompress/1k/fflate', () => { gunzipSync(gzipSeq1k); });
bench.add('gzip/decompress/100k/fflate', () => { gunzipSync(gzipSeq100k); });

// ============================================================
// Zlib compress — 2 sizes = 2
// ============================================================

bench.add('zlib/compress/1k/fflate', () => { zlibSync(seq1k); });
bench.add('zlib/compress/100k/fflate', () => { zlibSync(seq100k); });

// ============================================================
// Zlib decompress — 2 sizes = 2
// ============================================================

bench.add('zlib/decompress/1k/fflate', () => { unzlibSync(zlibSeq1k); });
bench.add('zlib/decompress/100k/fflate', () => { unzlibSync(zlibSeq100k); });

// ============================================================
// ZIP compress/decompress = 2
// ============================================================

bench.add('zip/compress/fflate', () => { zipSync(zipFiles); });
bench.add('zip/decompress/fflate', () => { unzipSync(zippedData); });

// ============================================================
// Auto-detect decompress — 2 sizes = 2
// ============================================================

bench.add('decompress/auto_detect/1k/fflate', () => { decompressSync(gzipSeq1k); });
bench.add('decompress/auto_detect/100k/fflate', () => { decompressSync(gzipSeq100k); });

// ============================================================
// Run and report
// ============================================================

console.log('Running fflate benchmarks (20 tests)...\n');
await bench.run();
console.table(bench.table());
