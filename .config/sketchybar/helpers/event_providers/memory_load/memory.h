#include <mach/mach.h>
#include <stdbool.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/sysctl.h>

struct memory {
  mach_port_t host;
  vm_size_t page_size;

  uint64_t total_memory;
  uint64_t used_memory;
  uint64_t free_memory;

  int used_percent;
  int app_percent;
  int wired_percent;
  int compressed_percent;
};

static inline void memory_init(struct memory* mem) {
  mem->host = mach_host_self();
  host_page_size(mem->host, &mem->page_size);

  // Get total physical memory
  int mib[2] = { CTL_HW, HW_MEMSIZE };
  size_t size = sizeof(mem->total_memory);
  sysctl(mib, 2, &mem->total_memory, &size, NULL, 0);
}

static inline void memory_update(struct memory* mem) {
  vm_statistics64_data_t vm_stat;
  mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;

  kern_return_t error = host_statistics64(mem->host,
                                          HOST_VM_INFO64,
                                          (host_info64_t)&vm_stat,
                                          &count);

  if (error != KERN_SUCCESS) {
    printf("Error: Could not read memory statistics.\n");
    return;
  }

  // Calculate memory usage
  uint64_t active = (uint64_t)vm_stat.active_count * mem->page_size;
  uint64_t inactive = (uint64_t)vm_stat.inactive_count * mem->page_size;
  uint64_t wired = (uint64_t)vm_stat.wire_count * mem->page_size;
  uint64_t compressed = (uint64_t)vm_stat.compressor_page_count * mem->page_size;
  uint64_t free_mem = (uint64_t)vm_stat.free_count * mem->page_size;
  uint64_t app_memory = (uint64_t)vm_stat.internal_page_count * mem->page_size
                       - (uint64_t)vm_stat.purgeable_count * mem->page_size;

  mem->used_memory = active + wired + compressed;
  mem->free_memory = free_mem + inactive;

  // Calculate percentages
  double total = (double)mem->total_memory;
  mem->used_percent = (int)((double)mem->used_memory / total * 100.0);
  mem->app_percent = (int)((double)app_memory / total * 100.0);
  mem->wired_percent = (int)((double)wired / total * 100.0);
  mem->compressed_percent = (int)((double)compressed / total * 100.0);
}
