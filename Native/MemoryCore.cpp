#include "MemoryCore.h"

#include <algorithm>
#include <array>
#include <atomic>
#include <bit>
#include <cmath>
#include <cstring>
#include <limits>
#include <mutex>
#include <string>
#include <variant>
#include <vector>

namespace {

using Numeric = std::variant<int64_t, uint64_t, double>;

struct Region {
    uint64_t identifier;
    std::string name;
    std::vector<uint8_t> bytes;
};

struct CandidateState {
    uint64_t identifier;
    uint64_t offset;
    std::array<uint8_t, 8> previous;
};

size_t type_size(mi_data_type type) {
    switch (type) {
    case MI_TYPE_INT8:
    case MI_TYPE_UINT8:
        return 1;
    case MI_TYPE_INT16:
    case MI_TYPE_UINT16:
        return 2;
    case MI_TYPE_INT32:
    case MI_TYPE_UINT32:
    case MI_TYPE_FLOAT32:
        return 4;
    case MI_TYPE_INT64:
    case MI_TYPE_UINT64:
    case MI_TYPE_FLOAT64:
        return 8;
    }
    return 0;
}

bool is_signed_type(mi_data_type type) {
    return type == MI_TYPE_INT8 || type == MI_TYPE_INT16 ||
           type == MI_TYPE_INT32 || type == MI_TYPE_INT64;
}

bool is_unsigned_type(mi_data_type type) {
    return type == MI_TYPE_UINT8 || type == MI_TYPE_UINT16 ||
           type == MI_TYPE_UINT32 || type == MI_TYPE_UINT64;
}

uint64_t load_unsigned(const uint8_t *bytes, size_t length, mi_byte_order order) {
    uint64_t value = 0;
    for (size_t index = 0; index < length; ++index) {
        const size_t shift_index = order == MI_BYTE_ORDER_LITTLE_ENDIAN
                                      ? index
                                      : length - index - 1;
        value |= static_cast<uint64_t>(bytes[index]) << (shift_index * 8U);
    }
    return value;
}

Numeric decode(const uint8_t *bytes, mi_data_type type, mi_byte_order order) {
    const size_t length = type_size(type);
    const uint64_t raw = load_unsigned(bytes, length, order);
    if (is_signed_type(type)) {
        switch (length) {
        case 1:
            return static_cast<int64_t>(std::bit_cast<int8_t>(static_cast<uint8_t>(raw)));
        case 2:
            return static_cast<int64_t>(std::bit_cast<int16_t>(static_cast<uint16_t>(raw)));
        case 4:
            return static_cast<int64_t>(std::bit_cast<int32_t>(static_cast<uint32_t>(raw)));
        default:
            return std::bit_cast<int64_t>(raw);
        }
    }
    if (is_unsigned_type(type)) {
        return raw;
    }
    if (type == MI_TYPE_FLOAT32) {
        const uint32_t bits = static_cast<uint32_t>(raw);
        return static_cast<double>(std::bit_cast<float>(bits));
    }
    return std::bit_cast<double>(raw);
}

bool valid_value(const uint8_t *value, size_t length, size_t expected) {
    return value != nullptr && length == expected;
}

bool same_numeric(const Numeric &left, const Numeric &right, double tolerance) {
    if (left.index() != right.index()) {
        return false;
    }
    if (const auto *a = std::get_if<double>(&left)) {
        const double b = std::get<double>(right);
        if (std::isnan(*a) || std::isnan(b)) {
            return false;
        }
        if (*a == b) {
            return true;
        }
        return std::abs(*a - b) <= tolerance;
    }
    return left == right;
}

int compare_numeric(const Numeric &left, const Numeric &right) {
    if (left.index() == 0) {
        const auto a = std::get<int64_t>(left);
        const auto b = std::get<int64_t>(right);
        return a < b ? -1 : (a > b ? 1 : 0);
    }
    if (left.index() == 1) {
        const auto a = std::get<uint64_t>(left);
        const auto b = std::get<uint64_t>(right);
        return a < b ? -1 : (a > b ? 1 : 0);
    }
    const double a = std::get<double>(left);
    const double b = std::get<double>(right);
    if (std::isnan(a) || std::isnan(b)) {
        return -2;
    }
    return a < b ? -1 : (a > b ? 1 : 0);
}

bool evaluate(mi_condition condition,
              const Numeric &current,
              const Numeric *previous,
              const Numeric *target,
              const Numeric *upper,
              double tolerance) {
    switch (condition) {
    case MI_CONDITION_EXACT:
        return target != nullptr && same_numeric(current, *target, tolerance);
    case MI_CONDITION_NOT_EQUAL:
        return target != nullptr && !same_numeric(current, *target, tolerance);
    case MI_CONDITION_GREATER:
        return target != nullptr && compare_numeric(current, *target) > 0;
    case MI_CONDITION_LESS:
        return target != nullptr && compare_numeric(current, *target) < 0;
    case MI_CONDITION_BETWEEN:
        return target != nullptr && upper != nullptr &&
               compare_numeric(current, *target) >= 0 &&
               compare_numeric(current, *upper) <= 0;
    case MI_CONDITION_UNKNOWN:
        return true;
    case MI_CONDITION_INCREASED:
        return previous != nullptr && compare_numeric(current, *previous) > 0;
    case MI_CONDITION_DECREASED:
        return previous != nullptr && compare_numeric(current, *previous) < 0;
    case MI_CONDITION_CHANGED:
        return previous != nullptr && !same_numeric(current, *previous, tolerance);
    case MI_CONDITION_UNCHANGED:
    case MI_CONDITION_EQUAL_TO_PREVIOUS:
        return previous != nullptr && same_numeric(current, *previous, tolerance);
    case MI_CONDITION_INCREASED_BY:
    case MI_CONDITION_DECREASED_BY: {
        if (previous == nullptr || target == nullptr) {
            return false;
        }
        const int direction = condition == MI_CONDITION_INCREASED_BY ? 1 : -1;
        if (current.index() == 0) {
            const auto delta = std::get<int64_t>(*target);
            const auto before = std::get<int64_t>(*previous);
            if ((direction > 0 && before > std::numeric_limits<int64_t>::max() - delta) ||
                (direction < 0 && before < std::numeric_limits<int64_t>::min() + delta)) {
                return false;
            }
            return std::get<int64_t>(current) == before + direction * delta;
        }
        if (current.index() == 1) {
            const auto delta = std::get<uint64_t>(*target);
            const auto before = std::get<uint64_t>(*previous);
            if (direction > 0) {
                return before <= std::numeric_limits<uint64_t>::max() - delta &&
                       std::get<uint64_t>(current) == before + delta;
            }
            return before >= delta && std::get<uint64_t>(current) == before - delta;
        }
        const double before = std::get<double>(*previous);
        const double delta = std::get<double>(*target);
        const double expected = before + static_cast<double>(direction) * delta;
        return !std::isnan(expected) &&
               std::abs(std::get<double>(current) - expected) <= tolerance;
    }
    }
    return false;
}

bool valid_condition(mi_condition condition) {
    return condition >= MI_CONDITION_EXACT &&
           condition <= MI_CONDITION_EQUAL_TO_PREVIOUS;
}

bool valid_initial_condition(mi_condition condition) {
    return condition == MI_CONDITION_EXACT ||
           condition == MI_CONDITION_NOT_EQUAL ||
           condition == MI_CONDITION_GREATER ||
           condition == MI_CONDITION_LESS ||
           condition == MI_CONDITION_BETWEEN ||
           condition == MI_CONDITION_UNKNOWN;
}

} // namespace

struct mi_engine {
    std::mutex mutex;
    std::atomic<bool> cancelled{false};
    std::vector<Region> regions;
    uint64_t next_region_identifier = 1;
    uint64_t next_candidate_identifier = 1;
    uint64_t active_region_identifier = 0;
    mi_data_type active_type = MI_TYPE_UINT8;
    mi_byte_order active_byte_order = MI_BYTE_ORDER_LITTLE_ENDIAN;
    size_t active_value_size = 0;
    double active_tolerance = 0;
    std::vector<CandidateState> candidates;
};

namespace {

Region *find_region(mi_engine *engine, uint64_t identifier) {
    const auto found = std::find_if(engine->regions.begin(), engine->regions.end(),
                                    [identifier](const Region &region) {
                                        return region.identifier == identifier;
                                    });
    return found == engine->regions.end() ? nullptr : &*found;
}

mi_status decode_operands(mi_data_type type,
                          mi_byte_order order,
                          mi_condition condition,
                          const uint8_t *value,
                          size_t value_length,
                          const uint8_t *upper_value,
                          size_t upper_value_length,
                          Numeric &target,
                          Numeric &upper) {
    const size_t expected = type_size(type);
    if (expected == 0) {
        return MI_STATUS_INVALID_ARGUMENT;
    }
    const bool uses_target = condition == MI_CONDITION_EXACT ||
                             condition == MI_CONDITION_NOT_EQUAL ||
                             condition == MI_CONDITION_GREATER ||
                             condition == MI_CONDITION_LESS ||
                             condition == MI_CONDITION_BETWEEN ||
                             condition == MI_CONDITION_INCREASED_BY ||
                             condition == MI_CONDITION_DECREASED_BY;
    if (uses_target && !valid_value(value, value_length, expected)) {
        return MI_STATUS_INVALID_VALUE;
    }
    if (condition == MI_CONDITION_BETWEEN &&
        !valid_value(upper_value, upper_value_length, expected)) {
        return MI_STATUS_INVALID_VALUE;
    }
    if (uses_target) {
        target = decode(value, type, order);
    }
    if (condition == MI_CONDITION_BETWEEN) {
        upper = decode(upper_value, type, order);
        const int range_order = compare_numeric(target, upper);
        if (range_order == -2 || range_order > 0) {
            return MI_STATUS_INVALID_VALUE;
        }
    }
    if (condition == MI_CONDITION_INCREASED_BY ||
        condition == MI_CONDITION_DECREASED_BY) {
        if (type == MI_TYPE_FLOAT32 || type == MI_TYPE_FLOAT64) {
            if (std::get<double>(target) < 0.0 || std::isnan(std::get<double>(target))) {
                return MI_STATUS_INVALID_VALUE;
            }
        } else if (is_signed_type(type) && std::get<int64_t>(target) < 0) {
            return MI_STATUS_INVALID_VALUE;
        }
    }
    return MI_STATUS_OK;
}

bool valid_tolerance(mi_data_type type, double tolerance) {
    return std::isfinite(tolerance) && tolerance >= 0.0 &&
           ((type == MI_TYPE_FLOAT32 || type == MI_TYPE_FLOAT64) || tolerance == 0.0);
}

} // namespace

extern "C" {

mi_engine *mi_engine_create(void) {
    try {
        return new mi_engine();
    } catch (...) {
        return nullptr;
    }
}

void mi_engine_destroy(mi_engine *engine) {
    delete engine;
}

mi_status mi_region_create(mi_engine *engine,
                           const char *name,
                           const uint8_t *bytes,
                           size_t length,
                           uint64_t *region_identifier) {
    if (engine == nullptr || name == nullptr || name[0] == '\0' ||
        bytes == nullptr || length == 0 || region_identifier == nullptr) {
        return MI_STATUS_INVALID_ARGUMENT;
    }
    try {
        std::lock_guard lock(engine->mutex);
        Region region{engine->next_region_identifier++, name,
                      std::vector<uint8_t>(bytes, bytes + length)};
        *region_identifier = region.identifier;
        engine->regions.push_back(std::move(region));
        return MI_STATUS_OK;
    } catch (...) {
        return MI_STATUS_INTERNAL_ERROR;
    }
}

mi_status mi_region_write(mi_engine *engine,
                          uint64_t region_identifier,
                          uint64_t offset,
                          const uint8_t *bytes,
                          size_t length) {
    if (engine == nullptr || bytes == nullptr || length == 0) {
        return MI_STATUS_INVALID_ARGUMENT;
    }
    try {
        std::lock_guard lock(engine->mutex);
        Region *region = find_region(engine, region_identifier);
        if (region == nullptr) {
            return MI_STATUS_NOT_FOUND;
        }
        if (offset > region->bytes.size() ||
            length > region->bytes.size() - static_cast<size_t>(offset)) {
            return MI_STATUS_INVALID_RANGE;
        }
        std::copy_n(bytes, length, region->bytes.begin() + static_cast<size_t>(offset));
        return MI_STATUS_OK;
    } catch (...) {
        return MI_STATUS_INTERNAL_ERROR;
    }
}

mi_status mi_scan(mi_engine *engine,
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
                  uint64_t *candidate_count) {
    if (engine == nullptr || candidate_count == nullptr ||
        !valid_initial_condition(condition) ||
        (byte_order != MI_BYTE_ORDER_LITTLE_ENDIAN &&
         byte_order != MI_BYTE_ORDER_BIG_ENDIAN) ||
        (alignment != 0 && alignment > 8)) {
        return MI_STATUS_INVALID_ARGUMENT;
    }
    const size_t width = type_size(type);
    if (width == 0 || (alignment != 0 && alignment > width) ||
        !valid_tolerance(type, float_tolerance)) {
        return MI_STATUS_INVALID_ARGUMENT;
    }
    Numeric target = int64_t{0};
    Numeric upper = int64_t{0};
    const mi_status operands_status = decode_operands(type, byte_order, condition,
                                                        value, value_length,
                                                        upper_value, upper_value_length,
                                                        target, upper);
    if (operands_status != MI_STATUS_OK) {
        return operands_status;
    }

    try {
        std::lock_guard lock(engine->mutex);
        Region *region = find_region(engine, region_identifier);
        if (region == nullptr) {
            return MI_STATUS_NOT_FOUND;
        }
        engine->cancelled.store(false, std::memory_order_relaxed);
        engine->candidates.clear();
        engine->active_region_identifier = region_identifier;
        engine->active_type = type;
        engine->active_byte_order = byte_order;
        engine->active_value_size = width;
        engine->active_tolerance = float_tolerance;
        const size_t step = alignment == 0 ? width : alignment;
        const size_t total = region->bytes.size() >= width
                                 ? ((region->bytes.size() - width) / step) + 1
                                 : 0;
        engine->candidates.reserve(total);
        for (size_t offset = 0, index = 0; offset + width <= region->bytes.size();
             offset += step, ++index) {
            if ((index & 0xFFFU) == 0U) {
                if (engine->cancelled.load(std::memory_order_relaxed)) {
                    engine->candidates.clear();
                    return MI_STATUS_CANCELLED;
                }
                if (progress != nullptr) {
                    progress(index, total, context);
                }
                if (engine->cancelled.load(std::memory_order_relaxed)) {
                    engine->candidates.clear();
                    return MI_STATUS_CANCELLED;
                }
            }
            const Numeric current = decode(region->bytes.data() + offset, type, byte_order);
            const bool matches = evaluate(condition, current, nullptr,
                                          condition == MI_CONDITION_UNKNOWN ? nullptr : &target,
                                          condition == MI_CONDITION_BETWEEN ? &upper : nullptr,
                                          float_tolerance);
            if (matches) {
                CandidateState candidate{};
                candidate.identifier = engine->next_candidate_identifier++;
                candidate.offset = static_cast<uint64_t>(offset);
                std::copy_n(region->bytes.data() + offset, width, candidate.previous.data());
                engine->candidates.push_back(candidate);
            }
        }
        if (progress != nullptr) {
            progress(total, total, context);
        }
        if (engine->cancelled.load(std::memory_order_relaxed)) {
            engine->candidates.clear();
            return MI_STATUS_CANCELLED;
        }
        *candidate_count = engine->candidates.size();
        return MI_STATUS_OK;
    } catch (...) {
        return MI_STATUS_INTERNAL_ERROR;
    }
}

mi_status mi_filter(mi_engine *engine,
                    mi_condition condition,
                    const uint8_t *value,
                    size_t value_length,
                    const uint8_t *upper_value,
                    size_t upper_value_length,
                    double float_tolerance,
                    mi_progress_callback progress,
                    void *context,
                    uint64_t *candidate_count) {
    if (engine == nullptr || candidate_count == nullptr ||
        !valid_condition(condition) || condition == MI_CONDITION_UNKNOWN) {
        return MI_STATUS_INVALID_ARGUMENT;
    }
    try {
        std::lock_guard lock(engine->mutex);
        if (!valid_tolerance(engine->active_type, float_tolerance)) {
            return MI_STATUS_INVALID_ARGUMENT;
        }
        Numeric target = int64_t{0};
        Numeric upper = int64_t{0};
        const mi_status operands_status = decode_operands(engine->active_type,
                                                            engine->active_byte_order,
                                                            condition, value, value_length,
                                                            upper_value, upper_value_length,
                                                            target, upper);
        if (operands_status != MI_STATUS_OK) {
            return operands_status;
        }

        Region *region = find_region(engine, engine->active_region_identifier);
        if (region == nullptr || engine->active_value_size == 0) {
            return MI_STATUS_NOT_FOUND;
        }
        engine->cancelled.store(false, std::memory_order_relaxed);
        const size_t total = engine->candidates.size();
        std::vector<CandidateState> matches;
        matches.reserve(total);
        for (size_t index = 0; index < total; ++index) {
            if ((index & 0xFFFU) == 0U) {
                if (engine->cancelled.load(std::memory_order_relaxed)) {
                    return MI_STATUS_CANCELLED;
                }
                if (progress != nullptr) {
                    progress(index, total, context);
                }
                if (engine->cancelled.load(std::memory_order_relaxed)) {
                    return MI_STATUS_CANCELLED;
                }
            }
            const auto &candidate = engine->candidates[index];
            const size_t offset = static_cast<size_t>(candidate.offset);
            if (offset > region->bytes.size() ||
                engine->active_value_size > region->bytes.size() - offset) {
                return MI_STATUS_INVALID_RANGE;
            }
            const Numeric current = decode(region->bytes.data() + offset,
                                           engine->active_type, engine->active_byte_order);
            const Numeric previous = decode(candidate.previous.data(),
                                            engine->active_type, engine->active_byte_order);
            const bool uses_target = condition == MI_CONDITION_EXACT ||
                                     condition == MI_CONDITION_NOT_EQUAL ||
                                     condition == MI_CONDITION_GREATER ||
                                     condition == MI_CONDITION_LESS ||
                                     condition == MI_CONDITION_BETWEEN ||
                                     condition == MI_CONDITION_INCREASED_BY ||
                                     condition == MI_CONDITION_DECREASED_BY;
            if (evaluate(condition, current, &previous,
                         uses_target ? &target : nullptr,
                         condition == MI_CONDITION_BETWEEN ? &upper : nullptr,
                         float_tolerance)) {
                CandidateState updated = candidate;
                std::copy_n(region->bytes.data() + offset, engine->active_value_size,
                            updated.previous.data());
                matches.push_back(updated);
            }
        }
        if (progress != nullptr) {
            progress(total, total, context);
        }
        if (engine->cancelled.load(std::memory_order_relaxed)) {
            return MI_STATUS_CANCELLED;
        }
        engine->candidates = std::move(matches);
        engine->active_tolerance = float_tolerance;
        *candidate_count = engine->candidates.size();
        return MI_STATUS_OK;
    } catch (...) {
        return MI_STATUS_INTERNAL_ERROR;
    }
}

mi_status mi_candidates_page(mi_engine *engine,
                             uint64_t page_index,
                             mi_candidate *output,
                             size_t capacity,
                             size_t *written,
                             uint64_t *total_candidates) {
    if (engine == nullptr || written == nullptr || total_candidates == nullptr ||
        output == nullptr || capacity != 250) {
        return MI_STATUS_INVALID_ARGUMENT;
    }
    std::lock_guard lock(engine->mutex);
    Region *region = find_region(engine, engine->active_region_identifier);
    if (region == nullptr) {
        return MI_STATUS_NOT_FOUND;
    }
    constexpr uint64_t page_size = 250;
    *total_candidates = engine->candidates.size();
    if (page_index > std::numeric_limits<uint64_t>::max() / page_size) {
        *written = 0;
        return MI_STATUS_OK;
    }
    const uint64_t start64 = page_index * page_size;
    if (start64 >= engine->candidates.size()) {
        *written = 0;
        return MI_STATUS_OK;
    }
    const size_t start = static_cast<size_t>(start64);
    const size_t count = std::min({capacity, static_cast<size_t>(page_size),
                                   engine->candidates.size() - start});
    for (size_t index = 0; index < count; ++index) {
        const auto &stored = engine->candidates[start + index];
        const size_t offset = static_cast<size_t>(stored.offset);
        if (offset > region->bytes.size() ||
            engine->active_value_size > region->bytes.size() - offset) {
            return MI_STATUS_INVALID_RANGE;
        }
        mi_candidate candidate{};
        candidate.identifier = stored.identifier;
        candidate.offset = stored.offset;
        candidate.value_size = static_cast<uint8_t>(engine->active_value_size);
        std::copy_n(region->bytes.data() + offset, engine->active_value_size,
                    candidate.value);
        output[index] = candidate;
    }
    *written = count;
    return MI_STATUS_OK;
}

mi_status mi_cancel(mi_engine *engine) {
    if (engine == nullptr) {
        return MI_STATUS_INVALID_ARGUMENT;
    }
    engine->cancelled.store(true, std::memory_order_relaxed);
    return MI_STATUS_OK;
}

const char *mi_status_message(mi_status status) {
    switch (status) {
    case MI_STATUS_OK:
        return "Success";
    case MI_STATUS_INVALID_ARGUMENT:
        return "Invalid argument";
    case MI_STATUS_NOT_FOUND:
        return "Requested region or scan is unavailable";
    case MI_STATUS_INVALID_RANGE:
        return "Range is outside the registered region";
    case MI_STATUS_INVALID_VALUE:
        return "Comparison value has an invalid size or value";
    case MI_STATUS_CANCELLED:
        return "Operation cancelled";
    case MI_STATUS_INTERNAL_ERROR:
        return "Internal allocation or runtime failure";
    }
    return "Unknown status";
}

} // extern "C"
