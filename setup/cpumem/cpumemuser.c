// User-space check of /dev/s10cpumem: pattern write/verify over the whole mapping, then read bandwidth
// (threads pinned to the given CPUs) on the mapping vs malloc'd memory. gcc -O2 -pthread
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>
#include <pthread.h>
#include <sched.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec * 1e-9; }
struct job { const uint64_t *p; size_t n; int cpu; double best; uint64_t sink; pthread_barrier_t *b; };
static void *rd(void *a) {
    struct job *j = a; cpu_set_t s; CPU_ZERO(&s); CPU_SET(j->cpu, &s); pthread_setaffinity_np(pthread_self(), sizeof s, &s);
    for (int r = 0; r < 6; r++) {
        pthread_barrier_wait(j->b); double t = now(); uint64_t x0 = 0, x1 = 0, x2 = 0, x3 = 0;
        for (size_t i = 0; i < j->n; i += 4) { x0 += j->p[i]; x1 += j->p[i+1]; x2 += j->p[i+2]; x3 += j->p[i+3]; }
        j->sink ^= x0 ^ x1 ^ x2 ^ x3; t = now() - t; if (r && (!j->best || t < j->best)) j->best = t;
        pthread_barrier_wait(j->b);
    }
    return NULL;
}
static double bw(const uint64_t *base, size_t slice, int *cpus, int n) {
    pthread_t t[8]; struct job j[8]; pthread_barrier_t b; pthread_barrier_init(&b, NULL, n);
    for (int i = 0; i < n; i++) { j[i] = (struct job){ base + i * slice / 8, slice / 8, cpus[i], 0, 0, &b }; pthread_create(&t[i], NULL, rd, &j[i]); }
    double worst = 0; for (int i = 0; i < n; i++) { pthread_join(t[i], NULL); if (j[i].best > worst) worst = j[i].best; }
    return slice * n / worst / 1e9;
}
int main(void) {
    size_t sz = 184UL << 20; int fd = open("/dev/s10cpumem", O_RDWR); if (fd < 0) { perror("open"); return 1; }
    uint64_t *p = mmap(NULL, sz, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0); if (p == MAP_FAILED) { perror("mmap"); return 1; }
    size_t n = sz / 8, bad = 0;
    for (size_t i = 0; i < n; i++) p[i] = i * 0x9e3779b97f4a7c15ULL ^ 0x1234;
    for (size_t i = 0; i < n; i++) bad += p[i] != (i * 0x9e3779b97f4a7c15ULL ^ 0x1234);
    printf("pattern: %zu bad words of %zu\n", bad, n);
    size_t slice = 32UL << 20; uint64_t *m = malloc(4 * slice); memset(m, 1, 4 * slice);
    int one[1] = {7}, m4[2] = {6, 7}, big[4] = {4, 5, 6, 7};
    printf("GB/s  1 thread (cpu7): window %.1f  malloc %.1f\n", bw(p, slice, one, 1), bw(m, slice, one, 1));
    printf("GB/s  M4 pair (6,7):   window %.1f  malloc %.1f\n", bw(p, slice, m4, 2), bw(m, slice, m4, 2));
    printf("GB/s  4 big (4-7):     window %.1f  malloc %.1f\n", bw(p, slice, big, 4), bw(m, slice, big, 4));
    return bad != 0;
}
