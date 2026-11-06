#include "MemoryCore.h"

#include <algorithm>
#include <array>
#include <cassert>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <vector>

namespace {

void require(mi_status actual, mi_status expected = MI_STATUS_OK) {
    if (actual != expected) {
        std::cerr << "Expected " << mi_status_message(expected) << ", got "
                  << mi_status_message(actual) << '\n';
        std::abort();
    }
}

std::array<uint8_t, 4> little_endian(int32_t value) {
    const auto raw = static_cast<uint32_t>(value);
    return {static_cast<uint8_t>(raw), static_cast<uint8_t>(raw >> 8U),
            static_cast<uint8_t>(raw >> 16U), static_cast<uint8_t>(raw >> 24U)};
}

void scan_and_filter_owned_region() {
    mi_engine *engine = mi_engine_create();
    assert(engine != nullptr);
    std::vector<uint8_t> bytes(16);
    size_t cursor = 0;
    for (int32_t value : {10, 20, 30, 20}) {
        const auto encoded = little_endian(value);
        std::copy(encoded.begin(), encoded.end(), bytes.begin() + static_cast<std::ptrdiff_t>(cursor));
        cursor += encoded.size();
    }
    uint64_t region = 0;
    require(mi_region_create(engine, "test-owned-values", bytes.data(), bytes.size(), &region));

    const auto target = little_endian(20);
    uint64_t count = 0;
    require(mi_scan(engine, region, MI_TYPE_INT32, MI_CONDITION_EXACT,
                    MI_BYTE_ORDER_LITTLE_ENDIAN, 0,
                    target.data(), target.size(), nullptr, 0, 0,
                    nullptr, nullptr, &count));
    assert(count == 2);

    const auto updated = little_endian(25);
    require(mi_region_write(engine, region, 4, updated.data(), updated.size()));
    require(mi_filter(engine, MI_CONDITION_INCREASED, nullptr, 0, nullptr, 0, 0,
                      nullptr, nullptr, &count));
    assert(count == 1);
    std::array<mi_candidate, 250> page{};
    size_t written = 0;
    uint64_t total = 0;
    require(mi_candidates_page(engine, 0, page.data(), page.size(), &written, &total));
    assert(written == 1 && total == 1);
    assert(page[0].offset == 4 && page[0].value_size == 4 && page[0].value[0] == 25);
    mi_engine_destroy(engine);
}

void unknown_scan_and_pagination() {
    mi_engine *engine = mi_engine_create();
    assert(engine != nullptr);
    std::vector<uint8_t> bytes(1200, 7);
    uint64_t region = 0;
    require(mi_region_create(engine, "pagination", bytes.data(), bytes.size(), &region));
    uint64_t count = 0;
    require(mi_scan(engine, region, MI_TYPE_UINT8, MI_CONDITION_UNKNOWN,
                    MI_BYTE_ORDER_LITTLE_ENDIAN, 1, nullptr, 0, nullptr, 0, 0,
                    nullptr, nullptr, &count));
    assert(count == 1200);
    std::array<mi_candidate, 250> page{};
    size_t written = 0;
    uint64_t total = 0;
    require(mi_candidates_page(engine, 4, page.data(), page.size(), &written, &total));
    assert(written == 200 && total == 1200);
    assert(page[0].offset == 1000 && page[199].offset == 1199);
    require(mi_candidates_page(engine, 5, page.data(), page.size(), &written, &total));
    assert(written == 0 && total == 1200);
    require(mi_candidates_page(engine, 0, page.data(), 251, &written, &total),
            MI_STATUS_INVALID_ARGUMENT);
    mi_engine_destroy(engine);
}

void big_endian_and_range_validation() {
    mi_engine *engine = mi_engine_create();
    assert(engine != nullptr);
    const std::array<uint8_t, 4> bytes{0, 0, 0, 42};
    uint64_t region = 0;
    require(mi_region_create(engine, "big-endian", bytes.data(), bytes.size(), &region));
    const std::array<uint8_t, 4> target{0, 0, 0, 42};
    uint64_t count = 0;
    require(mi_scan(engine, region, MI_TYPE_UINT32, MI_CONDITION_EXACT,
                    MI_BYTE_ORDER_BIG_ENDIAN, 0,
                    target.data(), target.size(), nullptr, 0, 0,
                    nullptr, nullptr, &count));
    assert(count == 1);
    require(mi_region_write(engine, region, 3, target.data(), target.size()),
            MI_STATUS_INVALID_RANGE);
    mi_engine_destroy(engine);
}

void absolute_filter_and_cancellation() {
    mi_engine *engine = mi_engine_create();
    assert(engine != nullptr);
    std::vector<uint8_t> bytes(12);
    size_t cursor = 0;
    for (int32_t value : {2, 5, 8}) {
        const auto encoded = little_endian(value);
        std::copy(encoded.begin(), encoded.end(), bytes.begin() + static_cast<std::ptrdiff_t>(cursor));
        cursor += encoded.size();
    }
    uint64_t region = 0;
    require(mi_region_create(engine, "filter-values", bytes.data(), bytes.size(), &region));
    uint64_t count = 0;
    require(mi_scan(engine, region, MI_TYPE_INT32, MI_CONDITION_UNKNOWN,
                    MI_BYTE_ORDER_LITTLE_ENDIAN, 0,
                    nullptr, 0, nullptr, 0, 0, nullptr, nullptr, &count));
    assert(count == 3);

    const auto changed = little_endian(12);
    require(mi_region_write(engine, region, 4, changed.data(), changed.size()));
    require(mi_filter(engine, MI_CONDITION_EXACT,
                      changed.data(), changed.size(), nullptr, 0, 0,
                      nullptr, nullptr, &count));
    assert(count == 1);
    std::array<mi_candidate, 250> page{};
    size_t written = 0;
    uint64_t total = 0;
    require(mi_candidates_page(engine, 0, page.data(), page.size(), &written, &total));
    assert(written == 1 && page[0].offset == 4);

    struct CancelContext {
        mi_engine *engine;
        bool cancelled = false;
    } context{engine};
    const auto cancel_on_progress = [](uint64_t, uint64_t, void *opaque) {
        auto *state = static_cast<CancelContext *>(opaque);
        if (!state->cancelled) {
            state->cancelled = true;
            require(mi_cancel(state->engine));
        }
    };
    require(mi_scan(engine, region, MI_TYPE_INT32, MI_CONDITION_UNKNOWN,
                    MI_BYTE_ORDER_LITTLE_ENDIAN, 0,
                    nullptr, 0, nullptr, 0, 0, cancel_on_progress, &context, &count),
            MI_STATUS_CANCELLED);
    mi_engine_destroy(engine);
}

} // namespace

int main() {
    scan_and_filter_owned_region();
    unknown_scan_and_pagination();
    big_endian_and_range_validation();
    absolute_filter_and_cancellation();
    std::cout << "MemoryCore tests passed\n";
}
