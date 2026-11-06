#ifndef MEMORY_CORE_H
#define MEMORY_CORE_H

#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32)
#define MI_EXPORT __declspec(dllexport)
#else
#define MI_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct mi_engine mi_engine;

typedef enum mi_status {
    MI_STATUS_OK = 0,
    MI_STATUS_INVALID_ARGUMENT = 1,
    MI_STATUS_NOT_FOUND = 2,
    MI_STATUS_INVALID_RANGE = 3,
    MI_STATUS_INVALID_VALUE = 4,
    MI_STATUS_CANCELLED = 5,
    MI_STATUS_INTERNAL_ERROR = 6
} mi_status;

typedef enum mi_data_type {
    MI_TYPE_INT8 = 0,
    MI_TYPE_UINT8 = 1,
    MI_TYPE_INT16 = 2,
    MI_TYPE_UINT16 = 3,
    MI_TYPE_INT32 = 4,
    MI_TYPE_UINT32 = 5,
    MI_TYPE_INT64 = 6,
    MI_TYPE_UINT64 = 7,
    MI_TYPE_FLOAT32 = 8,
    MI_TYPE_FLOAT64 = 9
} mi_data_type;

typedef enum mi_byte_order {
    MI_BYTE_ORDER_LITTLE_ENDIAN = 0,
    MI_BYTE_ORDER_BIG_ENDIAN = 1
} mi_byte_order;

typedef enum mi_condition {
    MI_CONDITION_EXACT = 0,
    MI_CONDITION_NOT_EQUAL = 1,
    MI_CONDITION_GREATER = 2,
    MI_CONDITION_LESS = 3,
    MI_CONDITION_BETWEEN = 4,
    MI_CONDITION_UNKNOWN = 5,
    MI_CONDITION_INCREASED = 6,
    MI_CONDITION_DECREASED = 7,
    MI_CONDITION_CHANGED = 8,
    MI_CONDITION_UNCHANGED = 9,
    MI_CONDITION_INCREASED_BY = 10,
    MI_CONDITION_DECREASED_BY = 11,
    MI_CONDITION_EQUAL_TO_PREVIOUS = 12
} mi_condition;

typedef struct mi_candidate {
    uint64_t identifier;
    uint64_t offset;
    uint8_t value[8];
    uint8_t value_size;
} mi_candidate;

typedef void (*mi_progress_callback)(uint64_t completed, uint64_t total, void *context);

MI_EXPORT mi_engine *mi_engine_create(void);
MI_EXPORT void mi_engine_destroy(mi_engine *engine);

/* Copies bytes into library-owned storage; no caller address is retained or scanned. */
MI_EXPORT mi_status mi_region_create(mi_engine *engine,
                                     const char *name,
                                     const uint8_t *bytes,
                                     size_t length,
                                     uint64_t *region_identifier);
MI_EXPORT mi_status mi_region_write(mi_engine *engine,
                                    uint64_t region_identifier,
                                    uint64_t offset,
                                    const uint8_t *bytes,
                                    size_t length);
MI_EXPORT mi_status mi_region_read(mi_engine *engine,
                                   uint64_t region_identifier,
                                   uint64_t offset,
                                   uint8_t *bytes,
                                   size_t length);

/* Values use the selected byte order. Previous-value conditions require an existing scan. */
MI_EXPORT mi_status mi_scan(mi_engine *engine,
                            uint64_t region_identifier,
                            mi_data_type type,
                            mi_condition condition,
                            mi_byte_order byte_order,
                            uint32_t alignment,
                            const uint8_t *value,
                            size_t value_length,
                            const uint8_t *upper_value,
                            size_t upper_value_length,
                            double float_tolerance,
                            mi_progress_callback progress,
                            void *context,
                            uint64_t *candidate_count);

/* Filters the complete internal candidate set; page limits apply only to retrieval.
   Progress callbacks may call mi_cancel but must not re-enter other engine operations. */
MI_EXPORT mi_status mi_filter(mi_engine *engine,
                              mi_condition condition,
                              const uint8_t *value,
                              size_t value_length,
                              const uint8_t *upper_value,
                              size_t upper_value_length,
                              double float_tolerance,
                              mi_progress_callback progress,
                              void *context,
                              uint64_t *candidate_count);

MI_EXPORT mi_status mi_candidates_page(mi_engine *engine,
                                       uint64_t page_index,
                                       mi_candidate *output,
                                       size_t capacity,
                                       size_t *written,
                                       uint64_t *total_candidates);
MI_EXPORT mi_status mi_candidates_page_flat(mi_engine *engine,
                                             uint64_t page_index,
                                             uint64_t *identifiers,
                                             uint64_t *offsets,
                                             uint8_t *values,
                                             uint8_t *value_sizes,
                                             size_t capacity,
                                             size_t *written,
                                             uint64_t *total_candidates);
MI_EXPORT mi_status mi_cancel(mi_engine *engine);
MI_EXPORT const char *mi_status_message(mi_status status);

#ifdef __cplusplus
}
#endif

#endif
