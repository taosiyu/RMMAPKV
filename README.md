
####1.关于MMap
>什么是mmap?什么是内存映射?
好吧。其实百度下有很多解释，我在这边就稍微解释下：
mmap是一种内存映射文件的方法，即将一个文件或者其它对象映射到进程的地址空间，实现文件磁盘地址和进程虚拟地址空间中一段虚拟地址的一一对映关系。实现这样的映射关系后，进程就可以采用指针的方式读写操作这一段内存，而系统会自动回写脏页面到对应的文件磁盘上，即完成了对文件的操作而不必再调用read,write等系统调用函数。相反，内核空间对这段区域的修改也直接反映用户空间，从而可以实现不同进程间的文件共享。如下图 所示：

               ![image](http://upload-images.jianshu.io/upload_images/2193807-cb8ebc275462e58a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
               
               
>由上图可以看出，进程的虚拟地址空间，由多个虚拟内存区域构成。虚拟内存区域是进程的虚拟地址空间中的一个同质区间，即具有同样特性的连续地址范围。上图中所示的text数据段（代码段）、初始数据段、BSS数据段、堆、栈和内存映射，都是一个独立的虚拟内存区域。而为内存映射服务的地址空间处在堆栈之间的空余部分。
>linux内核使用vm_area_struct结构来表示一个独立的虚拟内存区域，由于每个不同质的虚拟内存区域功能和内部机制都不同，因此一个进程使用多个vm_area_struct结构来分别表示不同类型的虚拟内存区域。各个vm_area_struct结构使用链表或者树形结构链接，方便进程快速访问，如下图所示：
               
                        ![image](http://upload-images.jianshu.io/upload_images/2193807-807b1802d716de37.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
                        
>vm_area_struct结构中包含区域起始和终止地址以及其他相关信息，同时也包含一个vm_ops指针，其内部可引出所有针对这个区域可以使用的系统调用函数。这样，进程对某一虚拟内存区域的任何操作需要用要的信息，都可以从vm_area_struct中获得。mmap函数就是要创建一个新的vm_area_struct结构，并将其与文件的物理磁盘地址相连。

以上是基本的概念，这个技术其实是linux上运用的技术，当然其他操作系统也可以。那移动端是不是也可以利用这个技术呢？答案当然是可以，这次就利用mmap来制作一个本地存储的组件，致力于快速的存读和读取，抛弃NSUserdefault..= =
                        
###2.如何在移动端使用MMAP内存映射
>好吧，其实很简单，只是用到了一个方法。对没有看错，本质上就是这么一个方法，能让我们用到这个这么方便的机制，那么是哪个方法呢？如下：
<br> void *mmap(void *start,size_t length,int prot,int flags,int fd,off_t offsize); 
具体参数含义<br> 
>start ：  指向欲映射的内存起始地址，通常设为 NULL，代表让系统自动选定地址，映射成功后返回该地址。<br> 
length：  代表将文件中多大的部分映射到内存。<br> 
prot  ：  映射区域的保护方式。可以为以下几种方式的组合：<br> 
                        PROT_EXEC 映射区域可被执行<br> 
                        PROT_READ 映射区域可被读取<br> 
                        PROT_WRITE 映射区域可被写入<br> 
                        PROT_NONE 映射区域不能存取<br> 
flags ：  影响映射区域的各种特性。在调用mmap()时必须要指定MAP_SHARED 或MAP_PRIVATE。<br> 
MAP_FIXED 如果参数start所指的地址无法成功建立映射时，则放弃映射，不对地址做修正。通常不鼓励用此旗标。<br> 
 MAP_SHARED 对映射区域的写入数据会复制回文件内，而且允许其他映射该文件的进程共享。<br> 
MAP_PRIVATE 对映射区域的写入操作会产生一个映射文件的复制，即私人的“写入时复制”（copy on write）对此区域作的任何修改都不会写回原来的文件内容。<br> 
MAP_ANONYMOUS建立匿名映射。此时会忽略参数fd，不涉及文件，而且映射区域无法和其他进程共享。<br> 
MAP_DENYWRITE只允许对映射区域的写入操作，其他对文件直接写入的操作将会被拒绝。<br> 
MAP_LOCKED 将映射区域锁定住，这表示该区域不会被置换（swap）。<br> 
fd    ：  要映射到内存中的文件描述符。如果使用匿名内存映射时，即flags中设置了MAP_ANONYMOUS，fd设为-1。有些系统不支持匿名内存映射，则可以使用fopen打开/dev/zero文件，然后对该文件进行映射，可以同样达到匿名内存映射的效果。<br> 
offset：文件映射的偏移量，通常设置为0，代表从文件最前方开始对应，offset必须是PAGE_SIZE的整数倍。<br> 

>

                
基于上面的基础，很快就能建立出内存和沙盒文件的映射，有了映射，就能根据指针来存储数据啦^_^
                        
###3.关于存储和读取
不同的数据类型存储稍许有些不同，由于存储是以data形式存储，所以在存储时就要记录下key和value的长度，便于下次读取，这里我用的是一个16B的struct专门存储key和value的length数据，便于读取。<br> 
>struct DataItem {<br> 
           size_t keySize;    //key的长度8B<br> 
           size_t valueSize;  //value的长度8B<br> 
};<br> 
由于各种数据的差异性，读取和存储都有对应的方法，目前可以存读的数据是int32,uint32,int64,uint64,bool,string。后期还会进行扩展，目前是第一个版本。而本地的沙盒中的data文件，也会随着数据的不断增加，一开始是4kb，当后期存储不够时会进行扩展：<br> 
                        
>//查看现有存储大小够不够存储新数据
  -(BOOL)isHasFreeMemorySize:(size_t)newSize <br> 
<br> 好吧，为了保证数据的准确行，每次都会对数据大小进行crc32的验证，保存准确性。<br> 
 -(BOOL)checkFileCRCValid 
                        
###4.关于使用
>直接把MMAP文件和下面的文件拖入工程就能直接使用。
MMAPKV* mmkv = [MMAPKV defaultMMAPKV];

>[mmkv setInt32:1024 forKey:@"int32"];

>[mmkv getInt32ForKey:@"int32"]
                        
<br> 就是这么简单
###5.关于性能

直接上图<br> 
100000个int 连续存储 和 100000个string数据存储
>for (int i = 0; i< 100000; i++) {<br> 
	[mmkv setInt32:i forKey:[NSString stringWithFormat:@"intm%i",i]];<br> 
}<br> 
for (int i = 100000; i < 200000; i++) {<br> 
                        [mmkv setString:[NSString stringWithFormat:@"%i",i] forKey:[NSString stringWithFormat:@"string%i",i]];<br> 
}<br> 
                        ![image.png](https://upload-images.jianshu.io/upload_images/2193807-03ed568ef284d296.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
 性能提升巨大。。。。。
                        
