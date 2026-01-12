#include "memory.h"
#include "../sketchybar.h"

int main(int argc, char** argv) {
  float update_freq;
  if (argc < 3 || (sscanf(argv[2], "%f", &update_freq) != 1)) {
    printf("Usage: %s \"<event-name>\" \"<event_freq>\"\n", argv[0]);
    exit(1);
  }

  alarm(0);
  struct memory mem;
  memory_init(&mem);

  // Setup the event in sketchybar
  char event_message[512];
  snprintf(event_message, 512, "--add event '%s'", argv[1]);
  sketchybar(event_message);

  char trigger_message[512];
  for (;;) {
    // Acquire new info
    memory_update(&mem);

    // Prepare the event message
    snprintf(trigger_message,
             512,
             "--trigger '%s' used_percent='%02d' app_percent='%02d' wired_percent='%02d' compressed_percent='%02d' total_gb='%llu' used_gb='%llu'",
             argv[1],
             mem.used_percent,
             mem.app_percent,
             mem.wired_percent,
             mem.compressed_percent,
             mem.total_memory / (1024 * 1024 * 1024),
             mem.used_memory / (1024 * 1024 * 1024));

    // Trigger the event
    sketchybar(trigger_message);

    // Wait
    usleep(update_freq * 1000000);
  }
  return 0;
}
