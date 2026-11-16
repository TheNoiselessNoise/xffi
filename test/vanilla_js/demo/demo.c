#include <stdlib.h>
#include <string.h>

int add(int a, int b) { return a + b; }
int str_len(const char* s) { return (int)strlen(s); }

typedef int  (*binop_fn)(int, int);
typedef void (*notify_fn)(int, int);

int  call_binop(binop_fn f, int a, int b) { return f(a, b); }
void call_notify(notify_fn f, int a, int b) { f(a, b); }

typedef long long (*i64_fn)(long long, long long);
typedef float     (*f32_fn)(float, float);
typedef double    (*f64_fn)(double, double);

long long call_i64(i64_fn f, long long a, long long b) { return f(a, b); }
float     call_f32(f32_fn f, float a, float b)         { return f(a, b); }
double    call_f64(f64_fn f, double a, double b)       { return f(a, b); }

typedef struct { float x, y; }  Vec2;       // 8 bytes, indirect (sret / by pointer)
typedef struct { int id; double w; } Mixed; // id@0, pad, w@8, size 16
typedef struct { float v; }     Single;     // single scalar member: passed/returned directly

Vec2  vec2_add(Vec2 a, Vec2 b)     { return (Vec2){a.x + b.x, a.y + b.y}; }
Mixed make_mixed(int id, double w) { return (Mixed){id, w}; }
Single wrap_single(Single s)       { return (Single){s.v * 2.0f}; }

typedef Vec2 (*vec_fn)(Vec2);
Vec2 call_vecfn(vec_fn f, Vec2 v) { return f(v); }