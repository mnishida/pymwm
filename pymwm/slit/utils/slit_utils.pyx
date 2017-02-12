# -*- coding: utf-8 -*-
# cython: profile=False
cimport numpy as np
cimport cython
cimport scipy.linalg.cython_blas as blas


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
def coefs_cython(object hole, cdouble[::1] hs, cdouble w):
    cdef:
        long[::1] s_all = hole.s_all
        long[::1] n_all = hole.n_all
    As_array = np.empty(hole.num_n_all)
    Bs_array = np.empty(hole.num_n_all)
    cdef:
        double[::1] As = As_array
        double[::1] Bs = Bs_array
        cdouble e1 = hole.fill(w)
        cdouble e2 = hole.clad(w)
    if creal(e2) < -1e6:
        coefs_pec_C(
            &s_all[0], &n_all[0], hole.num_n_all, hole.r, &As[0], &Bs[0])
    else:
        coefs_C(
            &hs[0], w, &s_all[0], &n_all[0], hole.num_n_all,
            hole.r, e1, e2, &As[0], &Bs[0])
    return As_array, Bs_array


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef coefs_pec_C(long *s_all, long *n_all, int num_n_all,
              double r, double *As, double *Bs):
    cdef:
        int i, n
        double sqrt_r = sqrt(r)
        double sqrt_2 = sqrt(2.0)
    for i in range(num_n_all):
        n = n_all[i]
        if s_all[i] == 0:
            As[i] = sqrt_2 / sqrt_r
            Bs[i] = 0.0
        else:
            As[i] = 0.0
            if n == 0:
                Bs[i] = 1.0 / sqrt_r
            else:
                Bs[i] = sqrt_2 / sqrt_r


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef cdouble csinc(cdouble x) nogil:
    if cabs(x) < 1e-15:
        return 1.0 + 0.0j
    return csin(x) / x


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
cdef void coefs_C(
    cdouble *hs, cdouble w, long *s_all, long *n_all,
    int num_n_all, double r, cdouble e1, cdouble e2,
    double *As, double *Bs) nogil:
    cdef:
        int i, s, n, parity
        double norm, a, b
        cdouble uc, vc, ac, bc
        cdouble h, u, v
        cdouble B_A
    for i in range(num_n_all):
        n = n_all[i]
        h = hs[i]
        s = s_all[i]
        u = (1 + 1j) * csqrt(-0.5j * (e1 * w * w - h * h)) * r / 2
        v = (1 - 1j) * csqrt(0.5j * (- e2 * w * w + h * h)) * r / 2
        uc = u.conjugate()
        vc = v.conjugate()
        if n % 2 == 0:
            if s == 0:
                B_A = csin(u)
                parity = -1
                a = 1.0
                b = 0.0
            else:
                B_A = u / v * csin(u)
                parity = 1
                a = 0.0
                b = 1.0
        else:
            if s == 0:
                B_A = ccos(u)
                parity = 1
                a = 1.0
                b = 0.0
            else:
                B_A = - u / v * ccos(u)
                parity = -1
                a = 0.0
                b = 1.0
        norm = sqrt(creal(r * (cabs(B_A) ** 2  / (v + vc) +
                          (csinc(u - uc) + parity * csinc(u + uc)) / 2)))
        As[i] = a / norm
        Bs[i] = b / norm


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
def ABY_cython(cdouble w, double r, long[::1] s_all, long[::1] n_all,
               cdouble[::1] hs, cdouble e1, cdouble e2):
    cdef:
        int i, s, n, parity
        int num_n_all = n_all.shape[0]
        double sqrt_r = sqrt(r)
        double sqrt_2 = sqrt(2.0)
        cdouble h, u, v, y_in, y_out, B_A
    As_array = np.empty(num_n_all)
    Bs_array = np.empty(num_n_all)
    Ys_array = np.empty(num_n_all, dtype=np.complex)
    cdef:
        double[:] As = As_array
        double[:] Bs = Bs_array
        cdouble[:] Ys = Ys_array
    if creal(e2) < -1e6:
        coefs_pec_C(&s_all[0], &n_all[0], num_n_all, r, &As[0], &Bs[0])
    else:
        coefs_C(
            &hs[0], w, &s_all[0], &n_all[0], num_n_all,
            r, e1, e2, &As[0], &Bs[0])
    for i in range(num_n_all):
        h = hs[i]
        n = n_all[i]
        s = s_all[i]
        if s == 0:
            y_in = y_out = h / w
        else:
            y_in = e1 * w / h
            y_out = e2 * w / h
        if creal(e2) < -1e6:
            Ys[i] = y_in
        else:
            u = (1 + 1j) * csqrt(-0.5j * (e1 * w ** 2 - h ** 2)) * r / 2
            v = (1 - 1j) * csqrt(0.5j * (- e2 * w * w + h * h)) * r / 2
            if n % 2 == 0:
                if s == 0:
                    B_A = csin(u)
                    parity = -1
                else:
                    B_A = u / v * csin(u)
                    parity = 1
            else:
                if s == 0:
                    B_A = ccos(u)
                    parity = 1
                else:
                    B_A = - u / v * ccos(u)
                    parity = -1
            Ys[i] = (As[i] ** 2 + Bs[i] ** 2) * r * (
                y_out * B_A ** 2 / (2 * v) +
                (1.0 + parity * csinc(2 * u)) * y_in / 2)
    return As_array, Bs_array, Ys_array


@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
def uvABY_cython(cdouble w, double r, long[::1] s_all, long[::1] n_all,
                 cdouble[::1] hs, cdouble e1, cdouble e2):
    cdef:
        int i, s, n, parity
        int num_n_all = n_all.shape[0]
        double sqrt_r = sqrt(r)
        double sqrt_2 = sqrt(2.0)
        cdouble h, u, v, y_in, y_out, B_A
    us_array = np.empty(num_n_all, dtype=np.complex)
    vs_array = np.empty(num_n_all, dtype=np.complex)
    As_array = np.empty(num_n_all)
    Bs_array = np.empty(num_n_all)
    Ys_array = np.empty(num_n_all, dtype=np.complex)
    cdef:
        cdouble[:] us = us_array
        cdouble[:] vs = vs_array
        double[:] As = As_array
        double[:] Bs = Bs_array
        cdouble[:] Ys = Ys_array
    if creal(e2) < -1e6:
        coefs_pec_C(&s_all[0], &n_all[0], num_n_all, r, &As[0], &Bs[0])
    else:
        coefs_C(
            &hs[0], w, &s_all[0], &n_all[0], num_n_all,
            r, e1, e2, &As[0], &Bs[0])
    for i in range(num_n_all):
        h = hs[i]
        u = (1 + 1j) * csqrt(-0.5j * (e1 * w ** 2 - h ** 2)) * r / 2
        v = (1 - 1j) * csqrt(0.5j * (- e2 * w * w + h * h)) * r / 2
        n = n_all[i]
        s = s_all[i]
        if s == 0:
            y_in = y_out = h / w
        else:
            y_in = e1 * w / h
            y_out = e2 * w / h
        if creal(e2) < -1e6:
            Ys[i] = y_in
        else:
            if n % 2 == 0:
                if s == 0:
                    B_A = csin(u)
                    parity = -1
                else:
                    B_A = u / v * csin(u)
                    parity = 1
            else:
                if s == 0:
                    B_A = ccos(u)
                    parity = 1
                else:
                    B_A = - u / v * ccos(u)
                    parity = -1
            Ys[i] = (As[i] ** 2 + Bs[i] ** 2) * r * (
                y_out * B_A ** 2 / (2 * v) +
                (1.0 + parity * csinc(2 * u)) * y_in / 2)
        us[i] = u
        vs[i] = v
    return us_array, vs_array, As_array, Bs_array, Ys_array
