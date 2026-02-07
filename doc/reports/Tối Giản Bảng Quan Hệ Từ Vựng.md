# **Báo cáo Nghiên cứu Chuyên sâu: Thiết kế Bộ nhãn Quan hệ Phụ thuộc Tối giản cho Định nghĩa Ngữ nghĩa Từ vựng (Word Sense Disambiguation) trong Dịch máy Trung-Việt**

## **Tóm tắt Điều hành**

Báo cáo này đề xuất một giải pháp kỹ thuật nhằm giải quyết vấn đề đa nghĩa trong dịch máy Trung-Việt, cụ thể là thiết kế một **Bảng Dependency Relation Tags (Nhãn Quan hệ Phụ thuộc) Tối giản**. Mục tiêu cốt lõi là tạo ra một lớp ánh xạ ngữ nghĩa (semantic layer) phục vụ riêng cho việc tra cứu từ điển và khớp nghĩa theo cặp từ (pair-based lexical matching), trong khi vẫn duy trì bộ nhãn gốc (HanLP/Stanford Dependencies) cho các tác vụ phân tích cú pháp và tái sắp xếp câu (reordering).  
Thông qua việc phân tích sâu các đặc trưng ngôn ngữ học đối chiếu giữa tiếng Trung và tiếng Việt, cùng với việc mổ xẻ kỹ lưỡng bộ nhãn Stanford Dependencies (SD) mà HanLP sử dụng, báo cáo xác định rằng hơn 45 nhãn cú pháp hiện tại có thể được tối giản xuống còn **5 Nhãn Ngữ nghĩa Cốt lõi (Core Semantic Relations)**. Sự tối giản này dựa trên nguyên tắc "Cùng Cặp \- Khác Nghĩa" (Same Pair \- Different Meaning), đảm bảo rằng sự phân biệt chỉ được giữ lại khi và chỉ khi sự thay đổi về quan hệ phụ thuộc dẫn đến sự thay đổi về từ vựng đích trong tiếng Việt.

## ---

**Chương 1: Cơ sở Lý luận và Định nghĩa Vấn đề**

### **1.1 Bản chất của Vấn đề Đa nghĩa trong Quan hệ Phụ thuộc**

Trong xử lý ngôn ngữ tự nhiên (NLP) cho tiếng Trung, việc phân tích phụ thuộc (dependency parsing) đóng vai trò then chốt vì tiếng Trung là ngôn ngữ đơn lập (isolating language), thiếu sự biến đổi hình thái (morphology) để đánh dấu chức năng ngữ pháp.1 Nghĩa của một từ thường được xác định bởi "bạn đồng hành" (collocate) của nó và mối quan hệ giữa chúng.  
Tuy nhiên, các bộ phân tích cú pháp hiện đại như HanLP, dựa trên chuẩn Stanford Dependencies (SD) hoặc Universal Dependencies (UD), được thiết kế để mô tả **cấu trúc cú pháp** (syntactic structure) chi tiết, chứ không phải **vai trò ngữ nghĩa** (semantic role) dùng cho dịch thuật.3  
**Vấn đề:** Một cặp từ $(W\_1, W\_2)$ có thể xuất hiện với nhiều nhãn quan hệ khác nhau trong cây cú pháp (ví dụ: nsubj, top, xsubj), nhưng trong tiếng Việt, bản dịch của chúng có thể không đổi. Việc lưu trữ tất cả các biến thể này trong từ điển làm tăng độ phức tạp (data sparsity) và giảm hiệu suất tra cứu. Ngược lại, có những trường hợp thay đổi quan hệ (ví dụ: từ dobj sang rcomp) sẽ làm thay đổi hoàn toàn nghĩa của từ.

### **1.2 Nguyên tắc Thiết kế: "Khớp Nghĩa theo Cặp"**

Yêu cầu của người dùng là thiết kế một bảng nhãn chỉ nhằm mục đích khớp nghĩa. Điều này dẫn đến một nguyên tắc thiết kế tiên quyết:  
**Nguyên tắc Phân biệt Tối thiểu:** Hai nhãn quan hệ cú pháp $R\_a$ và $R\_b$ chỉ nên được tách biệt trong bảng nhãn mới nếu tồn tại một cặp từ $(W\_{head}, W\_{dep})$ sao cho:

$$Translation(W\_{head} | W\_{dep}, R\_a) \\neq Translation(W\_{head} | W\_{dep}, R\_b)$$  
Nếu bản dịch không đổi, $R\_a$ và $R\_b$ phải được gộp (merge) thành một nhãn ngữ nghĩa chung. Cách tiếp cận này chuyển trọng tâm từ "Cú pháp bề mặt" (Surface Syntax) sang "Cấu trúc Đối mục sâu" (Deep Argument Structure).

### **1.3 Bối cảnh Ngôn ngữ Trung-Việt**

Dịch thuật Trung-Việt có những đặc thù riêng biệt so với Trung-Anh. Cả hai đều là ngôn ngữ SVO (Chủ-Động-Tân), nhưng có sự khác biệt lớn về:

1. **Cấu trúc Định ngữ:** Tiếng Trung là Head-Final (Định ngữ trước danh từ: *To nhà* \- 大房子), Tiếng Việt là Head-Initial (Định ngữ sau danh từ: *Nhà to*).  
2. **Bổ ngữ Kết quả (Resultative Complement):** Tiếng Trung sử dụng cấu trúc V-V chặt chẽ (看不见), tiếng Việt thường dùng V-Adv hoặc V-V rời rạc.  
3. **Giới từ và Động từ:** Nhiều giới từ tiếng Trung (在, 给) thực chất hoạt động như động từ trong tiếng Việt (*ở*, *cho*).

## ---

**Chương 2: Phân tích Phê phán Bộ nhãn Stanford/HanLP dưới góc độ Ngữ nghĩa**

Để thiết kế bộ nhãn tối giản, ta cần "giải phẫu" bộ nhãn gốc mà HanLP đang sử dụng.3 Bảng dưới đây phân loại các nhãn gốc và đánh giá mức độ cần thiết của chúng đối với việc định nghĩa từ vựng (WSD).

### **2.1 Nhóm Quan hệ Chủ ngữ (Subject Relations)**

HanLP phân biệt: nsubj (danh từ chủ ngữ), xsubj (chủ ngữ kiểm soát), top (chủ đề), nsubjpass (chủ ngữ bị động).

* **Phân tích:** Trong dịch Trung-Việt, sự khác biệt giữa nsubj (chủ ngữ thường) và top (chủ đề) thường không làm thay đổi nghĩa gốc của động từ. Ví dụ:  
  * nsubj: *Tôi* ăn táo (我吃苹果).  
  * top: *Táo*, tôi ăn rồi (苹果，我吃了).  
  * Trong cả hai trường hợp, quan hệ ngữ nghĩa giữa "Ăn" và "Táo" là Động từ \- Đối tượng (Verb-Patient), và quan hệ giữa "Ăn" và "Tôi" là Động từ \- Tác thể (Verb-Agent).  
* **Điểm Cốt yếu:** Nhãn nsubjpass (Chủ ngữ bị động) là một "cạm bẫy" cú pháp. Trong câu "Táo được ăn" (苹果被吃了), *Táo* là chủ ngữ ngữ pháp (nsubjpass), nhưng về mặt ngữ nghĩa, nó là **đối tượng chịu tác động**. Để khớp nghĩa từ điển, ta cần tìm nghĩa của động từ "Ăn" khi tác động lên "Táo". Do đó, nsubjpass nên được gộp vào nhóm Tân ngữ (dobj) thay vì Chủ ngữ (nsubj).5

### **2.2 Nhóm Quan hệ Tân ngữ (Object Relations)**

HanLP phân biệt: dobj (tân ngữ trực tiếp), range (tân ngữ đo lường), pobj (tân ngữ giới từ).

* **Phân tích:**  
  * dobj: Quan hệ cốt lõi nhất. Ví dụ: 打 (đánh) \+ 人 (người).  
  * range: Thường dùng cho số lượng. Ví dụ: 等 (đợi) \+ 一个小时 (một tiếng). Mặc dù cú pháp khác nhau, nhưng về mặt chọn nghĩa từ vựng, động từ 等 vẫn giữ nghĩa là "đợi".  
  * pobj: Phụ thuộc vào giới từ đứng trước (p). Tuy nhiên, trong tiếng Việt, giới từ tiếng Trung thường được dịch thành động từ. Ví dụ: 用 (dùng) \+ 刀 (dao). Quan hệ pobj ở đây xác định nghĩa của 用.

### **2.3 Nhóm Quan hệ Bổ ngữ và Định ngữ (Modifier/Complement Relations)**

Đây là khu vực phức tạp nhất và cần sự phân loại tinh tế nhất.6 HanLP phân biệt: nn, amod, advmod, assmod, rcomp, ccomp.

* **Xung đột Tiềm ẩn:**  
  * nn (Danh từ ghép): 电话 (Điện thoại) \+ 会议 (Hội nghị) \-\> *Hội nghị qua điện thoại*.  
  * dobj (Động tân): 打 (Gọi) \+ 电话 (Điện thoại).  
  * Nếu gộp nn và dobj (như một số hệ thống đơn giản), ta sẽ không phân biệt được danh từ ghép và cụm động tân, dẫn đến dịch sai cấu trúc.

## ---

**Chương 3: Kiến trúc Bộ nhãn Tối giản (Minimalist Semantic Tagset)**

Dựa trên phân tích trên và yêu cầu "tối giản", tôi đề xuất bộ nhãn gồm **5 Quan hệ Ngữ nghĩa (SEM)** và **1 Quan hệ Chức năng (FUNC)**. Đây là bộ lọc cuối cùng để tra cứu từ điển.

### **Bảng Định nghĩa Bộ nhãn Tối giản**

| Nhãn Tối giản (Proposed Tag) | Tên đầy đủ (Semantic Role) | Nhãn HanLP Gốc (Mapping Source) | Lý luận Tối giản hóa (Rationale) |
| :---- | :---- | :---- | :---- |
| **SEM-AGT** | **Agent / Experiencer** (Tác thể) | nsubj, xsubj, top, csubj | Đại diện cho chủ thể thực hiện hành động. Gộp top vào đây vì Chủ đề thường là Tác thể được đảo lên. |
| **SEM-PAT** | **Patient / Theme** (Đối tượng/Thụ thể) | dobj, nsubjpass, ba, range, pobj | **Quan trọng:** Gộp nsubjpass (chủ ngữ bị động) và ba (tân ngữ cấu trúc Ba) vào đây vì chúng đều là đối tượng chịu tác động về mặt ngữ nghĩa. Giúp tra cứu thống nhất nghĩa động từ bất kể thể bị động/chủ động. |
| **SEM-MOD** | **Modifier / Attribute** (Định ngữ/Bổ nghĩa) | nn, amod, advmod, assmod, nummod, clf, det, neg, ordmod, tmod | Gộp tất cả các quan hệ bổ nghĩa mang tính chất "tĩnh" (static) hoặc mô tả tính chất. Phân biệt rõ ràng với quan hệ hành động (AGT/PAT). |
| **SEM-COMP** | **Result / State** (Bổ ngữ Kết quả/Trạng thái) | rcomp, ccomp, xcomp, comod, dvpmod | Đặc thù cho dịch Trung-Việt. Xử lý các cụm V-V hoặc V-State (看不见, 跑得快) nơi nghĩa của động từ chính bị biến đổi bởi kết quả. |
| **SEM-LOC** | **Location / Scope** (Phương vị/Phạm vi) | loc, lobj, plmod, lccomp, prep (khi mang nghĩa địa điểm) | Tách riêng vì tiếng Trung dùng Phương vị từ (上, 下) rất nhiều, và chúng thường dịch thành giới từ hoặc động từ trong tiếng Việt (*trên*, *dưới*). |
| **FUNC** | **Functional / Ignored** (Hư từ/Chức năng) | punct, asp, etc, discourse, aux, auxpass, cop | Các nhãn này thường không thay đổi nghĩa gốc của từ vựng (lemma). Chúng được xử lý ở tầng cú pháp, không cần tham gia vào tầng tra cứu nghĩa từ vựng. |

## ---

**Chương 4: Phân tích Xung đột Ngữ nghĩa: "Cùng Cặp \- Khác Nghĩa"**

Đây là phần trọng tâm nhất để trả lời yêu cầu của bạn: *"kiểm tra lại cho tôi và tối giản về các loại quan hệ mà cùng một cặp từ có thể sinh ra các nghĩa khác nhau"*. Chúng ta sẽ chứng minh tại sao 5 nhãn trên là cần thiết và không thể gộp thêm được nữa bằng phương pháp phản chứng (proof by contradiction) thông qua các cặp từ cụ thể.

### **4.1 Xung đột giữa SEM-AGT (Tác thể) và SEM-PAT (Thụ thể)**

**Giả thuyết:** Có thể gộp Chủ ngữ và Tân ngữ thành một nhãn ARG (Đối số) không?  
**Kiểm chứng:** Xét cặp từ **(Nước \- 水, Mở/Sôi \- 开)**.

1. **Trường hợp 1 (SEM-AGT):** 水 $\\xrightarrow{nsubj}$ 开 (Thủy khai).  
   * Ngữ cảnh: "Nước sôi" (Water boils).  
   * Nghĩa 开: *Sôi*.  
2. **Trường hợp 2 (SEM-PAT):** 开 $\\xrightarrow{dobj}$ 水 (Khai thủy).  
   * Ngữ cảnh: "Mở nước" (Turn on the water/tap).  
   * Nghĩa 开: *Mở*.  
     **Kết luận:** Cùng cặp từ, nhưng quan hệ Chủ ngữ và Tân ngữ tạo ra hai nghĩa tiếng Việt hoàn toàn khác nhau. **Không thể gộp SEM-AGT và SEM-PAT.**

### **4.2 Xung đột giữa SEM-PAT (Thụ thể) và SEM-MOD (Định ngữ)**

**Giả thuyết:** Có thể gộp Tân ngữ và Định ngữ thành một nhãn REL (Quan hệ) không?  
**Kiểm chứng:** Xét cặp từ **(Sách \- 书, Xem/Đọc \- 看)**.

1. **Trường hợp 1 (SEM-PAT):** 看 $\\xrightarrow{dobj}$ 书.  
   * Ngữ cảnh: "Đọc sách" (Read book).  
   * Nghĩa: Động từ \- Tân ngữ.  
2. **Trường hợp 2 (SEM-MOD):** 看 $\\xrightarrow{nn}$ 书 (Giả định trong cụm danh từ ghép, ví dụ: "Sách nhìn/Sách tranh" \- *Kan-shu*).  
   * Mặc dù cặp này ít gặp dạng nn, hãy xét cặp **(Toán \- 算, Pháp \- 法)**.  
   * dobj: 算 \+ 法 (Tính toán pháp luật \- ít dùng). Nghĩa: Động từ "Tính".  
   * nn: 算法 (Thuật toán \- Algorithm). Nghĩa: Danh từ ghép.  
     **Kết luận:** Quan hệ nn (Compound) tạo ra các từ ghép định danh, trong khi dobj tạo ra mệnh đề hành động. Trong tiếng Việt, nn thường dịch ngược trật tự (Thuật toán), còn dobj dịch xuôi (Tính pháp). **Không thể gộp SEM-PAT và SEM-MOD.**

### **4.3 Xung đột giữa SEM-MOD (Bổ nghĩa) và SEM-COMP (Bổ ngữ Kết quả)**

**Giả thuyết:** Có thể gộp Trạng ngữ (advmod) và Bổ ngữ kết quả (rcomp) không? Vì cả hai đều bổ nghĩa cho động từ?  
**Kiểm chứng:** Xét cặp từ **(Hảo/Tốt \- 好, Ăn \- 吃)**.

1. **Trường hợp 1 (SEM-MOD \- advmod):** 好 $\\xrightarrow{advmod}$ 吃 (Hảo cật).  
   * Ngữ cảnh: "Dễ ăn" hoặc "Ngon". (Ví dụ: 这饭很好吃 \- Cơm này rất ngon).  
   * Nghĩa 好: *Ngon/Dễ*.  
2. **Trường hợp 2 (SEM-COMP \- rcomp):** 吃 $\\xrightarrow{rcomp}$ 好 (Cật hảo).  
   * Ngữ cảnh: "Ăn xong" hoặc "Ăn no". (Ví dụ: 我吃好了 \- Tôi ăn xong rồi).  
   * Nghĩa 好: *Xong/No*.  
     **Kết luận:** Vị trí và loại quan hệ thay đổi hoàn toàn nghĩa của từ bổ trợ. Tiếng Việt phân biệt rất rõ "Ngon" (tính từ đứng trước/sau tùy ngữ cảnh) và "Xong" (từ chỉ hoàn thành). **Không thể gộp SEM-MOD và SEM-COMP.**

### **4.4 Xung đột giữa SEM-LOC (Phương vị) và SEM-PAT (Tân ngữ)**

**Giả thuyết:** Có thể coi Phương vị từ là Tân ngữ không?  
**Kiểm chứng:** Xét cặp từ **(Thượng \- 上, Bàn \- 桌子)**.

1. **Trường hợp 1 (SEM-LOC \- lobj):** 桌子 \+ 上.  
   * Ngữ cảnh: "Trên bàn" (On the table).  
   * Dịch: *Trên*.  
2. **Trường hợp 2 (SEM-PAT \- dobj):** 上 \+ 桌子 (Hành động).  
   * Ngữ cảnh: "Dọn món lên bàn" (Serve the table) hoặc "Lên bàn" (ngồi).  
   * Dịch: *Lên*.  
     **Kết luận:** Mặc dù tiếng Việt *Trên* và *Lên* có liên quan, nhưng về mặt từ loại và cú pháp dịch máy, một cái là Giới từ/Danh từ phương vị, một cái là Động từ chuyển động. **Cần tách riêng SEM-LOC.**

## ---

**Chương 5: Chiến lược Ánh xạ và Xử lý Bất quy tắc**

Sau khi đã thiết lập 5 nhãn cốt lõi, phần này mô tả chi tiết cách xử lý các trường hợp đặc biệt ("Grey Area") trong cú pháp Stanford Dependencies để đưa về bảng tối giản.

### **5.1 Xử lý Cấu trúc "De" (的/地/得)**

Trong cây cú pháp Stanford, từ hư từ "De" thường trở thành trung tâm của quan hệ assm (associative marker) hoặc cpm. Điều này làm gãy đôi quan hệ ngữ nghĩa giữa hai thực thể thực.  
**Chiến lược "Cầu nối" (Bridging Strategy):**

* **Đầu vào (HanLP):** Sách (Head) $\\xrightarrow{assmod}$ Của (Dependent) $\\xleftarrow{assm}$ Tôi. (Cấu trúc cây có thể biến thể tùy version HanLP).  
* **Thường gặp hơn:** Sách $\\xrightarrow{assmod}$ Tôi, và Tôi $\\xrightarrow{case/mark}$ Của.  
* **Quy tắc:** Nếu gặp các nhãn assm, cpm, prtmod trỏ vào hư từ (的, 之...), hệ thống tra cứu từ điển sẽ **bỏ qua hư từ** và thiết lập quan hệ trực tiếp giữa Head và Dependent còn lại.  
  * Ví dụ: Mỹ lệ (Adj) \+ de \+ Phong cảnh (Noun).  
  * Map thành: **(Phong cảnh, Mỹ lệ, SEM-MOD)**.  
  * Tra từ điển: Cặp (Phong cảnh, Mỹ lệ) với quan hệ MOD \-\> Dịch là "Cảnh đẹp".

### **5.2 Hợp nhất Thể Bị động (Passive Unification)**

Như đã đề cập, nsubjpass là chìa khóa để giảm bớt số lượng mục từ trong từ điển.

* **Quy tắc:** Mọi quan hệ nsubjpass (Chủ ngữ bị động) đều được ánh xạ về **SEM-PAT** (Tân ngữ).  
* **Lợi ích:** Bạn chỉ cần soạn một mục từ điển: (Ăn, Táo, SEM-PAT) \-\> Dịch: "Ăn táo". Khi gặp câu "Táo được ăn" (Táo là nsubjpass), hệ thống tự động chuyển thành SEM-PAT và tra được đúng nghĩa "Ăn", thay vì phải tạo mục từ riêng cho bị động.

### **5.3 Xử lý Động từ Ly hợp (Separable Verbs \- Liheci)**

8  
Động từ ly hợp (ví dụ: 吃饭 \- Ăn cơm, 睡觉 \- Ngủ) là thách thức lớn.

* **Phân tích:** Trong cú pháp, 吃 là Root, 饭 là dobj.  
* **Vấn đề:** Nếu dịch từng chữ: Ăn \+ Cơm. Nếu dịch cả cụm: Ăn uống/Dùng bữa.  
* **Giải pháp:** Ưu tiên tra cứu **SEM-PAT** trong từ điển cụm từ (Multi-word Expression Dictionary) trước.  
  * Nếu tìm thấy (吃, 饭, SEM-PAT) là một mục từ cố định \-\> Dịch là "Ăn cơm" hoặc "Dùng bữa" tùy định nghĩa.  
  * Nếu không \-\> Dịch rời từng từ theo cơ chế đơn lẻ.

## ---

**Chương 6: Ứng dụng vào Hệ thống và Dữ liệu Mẫu**

### **6.1 Bảng Dữ liệu Minh họa (Data Structure)**

Dưới đây là ví dụ về cách bảng dữ liệu từ điển của bạn sẽ trông như thế nào sau khi áp dụng bộ nhãn tối giản. Lưu ý sự gọn gàng so với việc dùng nhãn gốc.

| Head (Gốc) | Dependent (Phụ) | Relation (Tối giản) | Nghĩa Tiếng Việt (Head) | Nghĩa Tiếng Việt (Dep) | Ghi chú |
| :---- | :---- | :---- | :---- | :---- | :---- |
| **打** (Dǎ) | **电话** (Diànhuà) | **SEM-PAT** | Gọi | Điện thoại | Gộp dobj, ba |
| **打** (Dǎ) | **毛衣** (Máoyī) | **SEM-PAT** | Đan | Áo len | Gộp dobj |
| **打** (Dǎ) | **人** (Rén) | **SEM-PAT** | Đánh | Người | Gộp dobj, nsubjpass |
| **打** (Dǎ) | **死** (Sǐ) | **SEM-COMP** | Đánh | Chết | Gộp rcomp |
| **深** (Shēn) | **夜** (Yè) | **SEM-MOD** | Khuya/Sâu | Đêm | Gộp nn, amod |
| **深** (Shēn) | **红** (Hóng) | **SEM-MOD** | Đậm | Đỏ | Gộp advmod |
| **开** (Kāi) | **水** (Shuǐ) | **SEM-AGT** | Sôi | Nước | Nước sôi (nsubj) |
| **开** (Kāi) | **水** (Shuǐ) | **SEM-PAT** | Mở | Nước | Mở vòi (dobj) |

### **6.2 Lợi ích của Kiến trúc này**

1. **Giảm Nhiễu (Noise Reduction):** Loại bỏ các biến thể cú pháp không ảnh hưởng đến nghĩa (ví dụ: range vs dobj).  
2. **Tăng độ Phủ (Coverage):** Một mục từ điển SEM-PAT xử lý được cả câu chủ động, câu bị động (bei), và câu chữ ba.  
3. **Chính xác (Precision):** Vẫn giữ được sự phân biệt tinh tế giữa các cặp từ đa nghĩa nhờ 5 nhãn cốt lõi (như ví dụ 开水 ở trên).

## ---

**Kết luận**

Việc thiết kế bảng Dependency Relation Tags tối giản cho bài toán khớp nghĩa từ vựng Trung-Việt không phải là việc loại bỏ thông tin, mà là **cô đọng thông tin** (information distillation). Bằng cách chuyển đổi hơn 45 nhãn cú pháp của HanLP/Stanford thành **5 nhãn ngữ nghĩa chức năng (SEM-AGT, SEM-PAT, SEM-MOD, SEM-COMP, SEM-LOC)**, hệ thống của bạn sẽ đạt được sự cân bằng tối ưu giữa độ chính xác về nghĩa và hiệu suất tra cứu.  
Giải pháp này đáp ứng triệt để yêu cầu của người dùng:

1. **Mục đích khớp nghĩa:** Tập trung hoàn toàn vào sự thay đổi nghĩa của cặp từ.  
2. **Giữ nguyên Tagset gốc cho phân tích:** Bảng tối giản chỉ là lớp ánh xạ (mapping layer) phục vụ tra từ điển, không can thiệp vào quy trình parse cấu trúc để reordering sau này.  
3. **Tối giản hóa:** Chỉ giữ lại các quan hệ sinh ra nghĩa khác nhau (như đã chứng minh ở Chương 4).

Đây là bước nền tảng để xây dựng một hệ thống dịch máy lai (Hybrid MT) chất lượng cao, tận dụng sức mạnh của luật ngôn ngữ học để khắc phục điểm yếu của các mô hình thống kê thuần túy đối với các ngôn ngữ giàu ngữ cảnh như tiếng Trung và tiếng Việt.

### **Tài liệu Tham khảo & Trích dẫn**

* 1 Parsing Chinese Sentences with Grammatical Relations  
* 3 Stanford Dependencies Chinese (dep-sd\_zh.md)  
* 5 Stanford Dependencies Manual  
* 8 Separable Verbs in Chinese Grammar  
* 6 Chinese verb-resultative complement construction  
* 7 Directional verb compounds in Chinese dependencies  
* 10 Linguistic-Relationships Based Approach for Improving Word Alignment

#### **Works cited**

1. Parsing Chinese Sentences with Grammatical Relations | Computational Linguistics \- MIT Press Direct, accessed February 8, 2026, [https://direct.mit.edu/coli/article/45/1/95/1623/Parsing-Chinese-Sentences-with-Grammatical](https://direct.mit.edu/coli/article/45/1/95/1623/Parsing-Chinese-Sentences-with-Grammatical)  
2. Translation Prediction with Source Dependency-Based Context Representation \- AAAI, accessed February 8, 2026, [https://cdn.aaai.org/ojs/10978/10978-13-14506-1-2-20201228.pdf](https://cdn.aaai.org/ojs/10978/10978-13-14506-1-2-20201228.pdf)  
3. dep-sd\_zh.md  
4. A Comparison of Chinese Parsers for Stanford Dependencies \- ACL Anthology, accessed February 8, 2026, [https://aclanthology.org/P12-2003.pdf](https://aclanthology.org/P12-2003.pdf)  
5. Stanford typed dependencies manual, accessed February 8, 2026, [https://nlp.stanford.edu/software/dependencies\_manual.pdf](https://nlp.stanford.edu/software/dependencies_manual.pdf)  
6. Assessing Minimal Pairs of Chinese Verb-Resultative Complement Constructions: Insights from Language Models \- ACL Anthology, accessed February 8, 2026, [https://aclanthology.org/2025.cxgsnlp-1.14.pdf](https://aclanthology.org/2025.cxgsnlp-1.14.pdf)  
7. compound:dir : directional verb compound \- Universal Dependencies, accessed February 8, 2026, [https://universaldependencies.org/zh/dep/compound-dir.html](https://universaldependencies.org/zh/dep/compound-dir.html)  
8. “Separable Verbs” – A Misleading and Unnecessary Concept | mandarin friend 中文朋友, accessed February 8, 2026, [https://mandarinfriend.wordpress.com/2015/02/12/separable-verbs-a-misleading-concept-for-chinese-learners/](https://mandarinfriend.wordpress.com/2015/02/12/separable-verbs-a-misleading-concept-for-chinese-learners/)  
9. How does Vietnamese handle the equivalent of phrasal/separable verbs from English or Chinese? \- Linguistics Stack Exchange, accessed February 8, 2026, [https://linguistics.stackexchange.com/questions/45361/how-does-vietnamese-handle-the-equivalent-of-phrasal-separable-verbs-from-englis](https://linguistics.stackexchange.com/questions/45361/how-does-vietnamese-handle-the-equivalent-of-phrasal-separable-verbs-from-englis)  
10. Linguistic-Relationships-Based Approach for Improving Word Alignment \- ResearchGate, accessed February 8, 2026, [https://www.researchgate.net/publication/320436400\_Linguistic-Relationships-Based\_Approach\_for\_Improving\_Word\_Alignment](https://www.researchgate.net/publication/320436400_Linguistic-Relationships-Based_Approach_for_Improving_Word_Alignment)