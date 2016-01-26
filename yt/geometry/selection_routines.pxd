"""
Geometry selection routine imports.




"""

#-----------------------------------------------------------------------------
# Copyright (c) 2013, yt Development Team.
#
# Distributed under the terms of the Modified BSD License.
#
# The full license is in the file COPYING.txt, distributed with this software.
#-----------------------------------------------------------------------------

cimport numpy as np
from oct_visitors cimport Oct, OctVisitorData, \
    oct_visitor_function
from grid_visitors cimport GridTreeNode, GridVisitorData, \
    grid_visitor_function, check_child_masked
from yt.utilities.lib.ewah_bool_array cimport ewah_bool_array
from libcpp.map cimport map

ctypedef fused anyfloat:
    np.float32_t
    np.float64_t

cdef inline _ensure_code(arr):
    if hasattr(arr, "units"):
        if "code_length" == str(arr.units):
            return arr
        arr.convert_to_units("code_length")
    return arr

cdef class SelectorObject:
    cdef public np.int32_t min_level
    cdef public np.int32_t max_level
    cdef int overlap_cells
    cdef np.float64_t domain_width[3]
    cdef bint periodicity[3]

    cdef void recursively_visit_octs(self, Oct *root,
                        np.float64_t pos[3], np.float64_t dds[3],
                        int level,
                        oct_visitor_function *func,
                        OctVisitorData *data,
                        int visit_covered = ?)
    cdef void visit_oct_cells(self, OctVisitorData *data, Oct *root, Oct *ch,
                              np.float64_t spos[3], np.float64_t sdds[3],
                              oct_visitor_function *func, int i, int j, int k)
    cdef int select_grid(self, np.float64_t left_edge[3],
                               np.float64_t right_edge[3],
                               np.int32_t level, Oct *o = ?) nogil
    cdef int select_cell(self, np.float64_t pos[3], np.float64_t dds[3]) nogil

    cdef int select_point(self, np.float64_t pos[3]) nogil
    cdef int select_sphere(self, np.float64_t pos[3], np.float64_t radius) nogil
    cdef int select_bbox(self, np.float64_t left_edge[3],
                               np.float64_t right_edge[3]) nogil
    cdef int fill_mask_selector(self, np.float64_t left_edge[3],
                                np.float64_t right_edge[3], 
                                np.float64_t dds[3], int dim[3],
                                np.ndarray[np.uint8_t, ndim=3, cast=True] child_mask,
                                np.ndarray[np.uint8_t, ndim=3] mask,
                                int level)
    cdef void visit_grid_cells(self, GridVisitorData *data,
                    grid_visitor_function *func, np.uint8_t *cached_mask = ?)

    cdef void recursive_morton_mask(self, np.int32_t level,
                                     np.ndarray[np.float64_t, ndim=1] pos,
                                     np.ndarray[np.float64_t, ndim=1] dds,
                                     np.int32_t max_level, np.uint64_t mi1,
                                     map[np.uint64_t, ewah_bool_array] mm,
                                     int ngz = ?)

    # compute periodic distance (if periodicity set) assuming 0->domain_width[i] coordinates
    cdef np.float64_t difference(self, np.float64_t x1, np.float64_t x2, int d) nogil

cdef class AlwaysSelector(SelectorObject):
    pass

cdef class OctreeSubsetSelector(SelectorObject):
    cdef public SelectorObject base_selector
    cdef public np.int64_t domain_id

cdef inline np.float64_t _periodic_dist(np.float64_t x1, np.float64_t x2,
                                        np.float64_t dw, bint periodic) nogil:
    cdef np.float64_t rel = x1 - x2
    if not periodic: return rel
    if rel > dw * 0.5:
        rel -= dw
    elif rel < -dw * 0.5:
        rel += dw
    return rel
