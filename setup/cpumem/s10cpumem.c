// SPDX-License-Identifier: GPL-2.0
/*
 * s10cpumem: expose a reserved (no-map) physical range as /dev/s10cpumem for CPU-only use (mmap, cacheable).
 * Default range: the Galaxy S10's modem_if carve-out minus its first MB (the bootloader writes the modem TOC there):
 * 0xf0100000-0xfb8fffff, 184 MB. Linux never hands this memory to the page allocator, so no device ever DMAs into
 * it (device access to this window fails: giving it to Linux as normal RAM hangs the boot); only the process
 * that maps it touches it, with the CPU. It reads at ~8 GB/s per M4 pair (normal RAM: ~24).
 * The range must be a reserved-memory region absent from the kernel's linear map; the module refuses System RAM.
 */
#include <linux/module.h>
#include <linux/miscdevice.h>
#include <linux/fs.h>
#include <linux/mm.h>
#include <linux/io.h>
#include <linux/ioport.h>
#include <linux/atomic.h>

static unsigned long base = 0xf0100000, size = 0xb800000;
module_param(base, ulong, 0444);
module_param(size, ulong, 0444);

/* One user at a time: a second process mapping the range would overwrite the first one's data. Counted per VMA
 * (a split VMA counts twice), so a new mmap is refused until every VMA of the previous one is gone. */
static atomic_t s10cpumem_vmas = ATOMIC_INIT(0);

static void s10cpumem_vm_open(struct vm_area_struct *vma) { atomic_inc(&s10cpumem_vmas); }
static void s10cpumem_vm_close(struct vm_area_struct *vma) { atomic_dec(&s10cpumem_vmas); }
static const struct vm_operations_struct s10cpumem_vm_ops = {
	.open = s10cpumem_vm_open,
	.close = s10cpumem_vm_close,
};

static int s10cpumem_mmap(struct file *f, struct vm_area_struct *vma)
{
	unsigned long len = vma->vm_end - vma->vm_start, off = vma->vm_pgoff << PAGE_SHIFT;
	int ret;

	if (off >= size || len > size - off)
		return -EINVAL;
	if (atomic_cmpxchg(&s10cpumem_vmas, 0, 1) != 0)
		return -EBUSY;
	vm_flags_set(vma, VM_IO | VM_PFNMAP | VM_DONTEXPAND | VM_DONTDUMP | VM_DONTCOPY);
	vma->vm_ops = &s10cpumem_vm_ops;
	/* vm_page_prot stays the default for a shared mapping: Normal, write-back cacheable */
	ret = remap_pfn_range(vma, vma->vm_start, (base + off) >> PAGE_SHIFT, len, vma->vm_page_prot);
	if (ret)
		atomic_set(&s10cpumem_vmas, 0);
	return ret;
}

static const struct file_operations s10cpumem_fops = {
	.owner = THIS_MODULE,
	.mmap = s10cpumem_mmap,
};

static struct miscdevice s10cpumem_dev = {
	.minor = MISC_DYNAMIC_MINOR,
	.name = "s10cpumem",
	.fops = &s10cpumem_fops,
	.mode = 0600,
};

static int __init s10cpumem_init(void)
{
	if (!base || !size || (base | size) & ~PAGE_MASK)
		return -EINVAL;
	if (pfn_is_map_memory(base >> PAGE_SHIFT) || pfn_is_map_memory((base + size - 1) >> PAGE_SHIFT) ||
	    region_intersects(base, size, IORESOURCE_SYSTEM_RAM, IORES_DESC_NONE) != REGION_DISJOINT) {
		pr_err("s10cpumem: %#lx+%#lx overlaps System RAM, refusing\n", base, size);
		return -EINVAL;
	}
	pr_info("s10cpumem: /dev/s10cpumem = %#lx+%#lx (%lu MB, CPU-only)\n", base, size, size >> 20);
	return misc_register(&s10cpumem_dev);
}

static void __exit s10cpumem_exit(void)
{
	misc_deregister(&s10cpumem_dev);
}

module_init(s10cpumem_init);
module_exit(s10cpumem_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("CPU-only access to a reserved physical range (S10 modem carve-out)");
