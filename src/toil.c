/* Based on GNU coreutils' tail, hence the name.  Take a list of files as
 * arguments, and return 0 when a change is detected to any of them.  Returns
 * non-zero if there are any problems.
 *
 * TODO: Better error output.
 * TODO: Customisable sleep times.
 * TODO: Maximum sleep time.
 * TODO: Verbose output that lists which file changed when exiting.
 */

#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>

struct file_info {
	int fd;
	off_t size;
	struct timespec mtime;
	mode_t mode;
};

void record_starting_state(
		int num_files,
		char **filenames,
		struct file_info *files)
{
	struct stat stats;
	int ii;

	for (ii = 0; ii < num_files; ii++) {
		files[ii].fd = open(filenames[ii], O_RDONLY | O_BINARY);

		if (files[ii].fd == -1) {
			exit(43);
		}

		if (fstat(files[ii].fd, &stats) != 0) {
			exit(44);
		}

		if (!S_ISREG(stats.st_mode)) {
			exit(45);
		}

		files[ii].mtime = stats.st_mtim;
		files[ii].mode = stats.st_mode;
		files[ii].size = stats.st_size;
	}
}

void wait_for_change(int num_files, struct file_info *files)
{
	struct stat stats;
	int ii;

	for (;;) {
		sleep(1);

		for (ii = 0; ii < num_files; ii++) {
			if (fstat(files[ii].fd, &stats) != 0) {
				exit(42);
			}

			if (files[ii].mode != stats.st_mode
			    || files[ii].size != stats.st_size
			    || files[ii].mtime.tv_sec != stats.st_mtim.tv_sec
			    || files[ii].mtime.tv_nsec != stats.st_mtim.tv_nsec)
			{
				return;
			}
		}
	}
}

int main (int argc, char **argv)
{
	struct file_info *files;

	files = malloc(argc * sizeof *files);

	record_starting_state(argc, argv, files);
	wait_for_change(argc, files);
}
