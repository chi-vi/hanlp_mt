# **Tài liệu Hướng dẫn Kỹ thuật & Lộ trình Triển khai Engine Dịch thuật Hybrid Trung \- Việt (HanLP MTL)**

## **1\. Tổng quan Điều hành & Kiến trúc Hệ thống**

### **1.1. Tầm nhìn và Phạm vi**

Trong bối cảnh Dịch máy (Machine Translation \- MT) hiện đại, trong khi các mô hình Neural (NMT) chiếm ưu thế về độ mượt mà, chúng thường gặp khó khăn trong việc đảm bảo độ chính xác về mặt cấu trúc và thuật ngữ chuyên ngành, đặc biệt là đối với cặp ngôn ngữ có sự tương đồng về từ vựng (Sino-Vietnamese) nhưng khác biệt sâu sắc về trật tự từ như Trung \- Việt. Tài liệu này cung cấp một lộ trình kỹ thuật toàn diện để xây dựng một **Engine Dịch thuật Rule-based/Hybrid**, tận dụng sức mạnh của **HanLP Multi-Task Learning (MTL)**.  
Mục tiêu cốt lõi là chuyển đổi quy trình dịch thuật từ một "hộp đen" (black-box) sang một đường ống (pipeline) minh bạch, có thể kiểm soát và tinh chỉnh được: **Phân tích (Parse) $\\rightarrow$ Tái cấu trúc (Restructure) $\\rightarrow$ Chuyển đổi (Transform) $\\rightarrow$ Khử mơ hồ (Disambiguate) $\\rightarrow$ Sinh ngữ (Generate)**.

### **1.2. Kiến trúc HanLP MTL và Dữ liệu Đầu vào**

Hệ thống được xây dựng dựa trên mô hình HanLP MTL, cung cấp đồng thời các lớp thông tin ngôn ngữ học cần thiết cho việc ra quyết định dịch thuật chính xác.1

* **Tokenization (TOK):** Phân đoạn từ mịn (fine-grained) để xử lý các từ ghép phức tạp.  
* **Part-of-Speech (POS):** Sử dụng bộ nhãn CTB (Chinese Treebank), cung cấp thông tin từ loại chi tiết (ví dụ: VV cho động từ, NR cho tên riêng, BA cho câu chữ Bả).3  
* **Named Entity Recognition (NER):** Dựa trên chuẩn OntoNotes, nhận diện các thực thể như PERSON, ORG, GPE, DATE để phục vụ cơ chế dịch đặc biệt.1  
* **Constituency Parsing (CON):** Cung cấp cây cú pháp CTB, làm cơ sở cho các luật chuyển đổi cấu trúc phạm vi lớn (phrase-level).6  
* **Dependency Parsing (DEP):** Cung cấp quan hệ phụ thuộc để khử mơ hồ từ vựng (Word Sense Disambiguation).8

## ---

**2\. Chiến thuật Tái cấu trúc Cây ngữ pháp (Tree Restructuring Strategy)**

Một trong những thách thức lớn nhất khi làm việc với cây cú pháp Penn Chinese Treebank (CTB) trong dịch máy là cấu trúc "phẳng" (flat structure) của nó.10 Một node cha (ví dụ: VP) thường quản lý trực tiếp quá nhiều node con mà không có sự phân tầng rõ ràng, gây khó khăn cho việc áp dụng các luật đệ quy (recursive rules).

### **2.1. Vấn đề "Cây phẳng" và Nhu cầu Nhị phân hóa**

Trong CTB, một cụm động từ phức tạp như "đã làm việc ở Bắc Kinh ba năm" có thể được biểu diễn phẳng như sau:  
VP \-\> PP(tại Bắc Kinh) \+ VV(làm việc) \+ AS(đã/rồi) \+ QP(ba năm).  
Cấu trúc này gây khó khăn cho thuật toán dịch vì nó không chỉ rõ mối quan hệ kết hợp nào chặt chẽ hơn (ví dụ: động từ kết hợp với bổ ngữ thời lượng trước hay giới từ chỉ địa điểm trước). Để dịch sang tiếng Việt (nơi trật tự từ bị đảo lộn mạnh mẽ), chúng ta cần một cấu trúc cây **Nhị phân (Binary Tree)** hoặc ít nhất là phân tầng sâu hơn.10

### **2.2. Thuật toán Nhị phân hóa dựa trên Node Trưởng (Head-Driven Binarization)**

Thay vì sử dụng các phương pháp nhị phân hóa trái (left-binarization) hoặc phải (right-binarization) một cách máy móc, chúng tôi đề xuất chiến thuật **Head-Driven Binarization**. Phương pháp này bảo toàn tính trung tâm của từ chính (head word) trong cụm từ, tạo ra các "Semantic Chunks" (khối ngữ nghĩa) hợp lý.7

#### **2.2.1. Quy tắc Tìm Node Trưởng (Head-Finding Rules)**

Bước đầu tiên là xác định node con nào giữ vai trò trung tâm ngữ pháp trong một node cha. Dựa trên các nghiên cứu về CTB 13, bảng ưu tiên (priority list) sau được áp dụng:

| Node Cha | Hướng Tìm kiếm | Danh sách Ưu tiên Node Con (Head) | Ghi chú |
| :---- | :---- | :---- | :---- |
| **VP** (Cụm động từ) | Trái $\\rightarrow$ Phải | VE, VC, VV, VNV, VPT, VRD, VSB, VCD, VP | Ưu tiên động từ chính, động từ tồn tại (VE) hoặc là (VC). |
| **NP** (Cụm danh từ) | Phải $\\rightarrow$ Trái | NP, NN, IP, NR, NT | Danh từ trung tâm thường nằm cuối cùng trong tiếng Trung. |
| **PP** (Cụm giới từ) | Trái $\\rightarrow$ Phải | P, PP | Giới từ (P) là trưởng của cụm giới từ. |
| **CP** (Cụm bổ ngữ) | Phải $\\rightarrow$ Trái | DEC, CP, IP, VP | DEC (của/mà) hoặc mệnh đề là nòng cốt. |
| **DNP** (Định ngữ) | Phải $\\rightarrow$ Trái | DEG, DNP, DEC, QP | Trợ từ kết cấu DEG (的) thường được coi là điểm neo. |
| **LCP** (Cụm phương vị) | Phải $\\rightarrow$ Trái | LCP, LC | Từ chỉ phương vị (trên, dưới, trong). |

#### **2.2.2. Quy trình Gom nhóm Semantic Chunks**

Sau khi xác định được Head ($H$), thuật toán sẽ phân tách các node con còn lại thành hai nhóm: **Tiền phụ tố (Pre-modifiers)** và **Hậu phụ tố (Post-complements)**.  
**Thuật toán (Pseudocode Logic):**

1. **Input:** Node cha $P$ có các con $C\_1, C\_2, \\dots, C\_n$.  
2. **Find Head:** Tìm $C\_k$ là Head dựa trên bảng ưu tiên.  
3. **Partition:**  
   * Left List $L \= \[C\_1, \\dots, C\_{k-1}\]$  
   * Right List $R \= \[C\_{k+1}, \\dots, C\_n\]$  
4. **Chomsky Adjunction (Tạo tầng):**  
   * Nếu $L$ không rỗng: Tạo node trung gian $P^\*$ chứa ($H$ và phần tử cuối của $L$). Gán $P^\*$ làm $H$ mới. Lặp lại cho đến khi hết $L$. Việc này tạo ra cấu trúc cây nghiêng trái, gom các bổ ngữ gần động từ nhất vào một khối trước.  
   * Tương tự xử lý $R$ để tạo các lớp bổ ngữ sau.  
5. **Output:** Cây nhị phân với các nhãn trung gian (ví dụ @VP, @NP).

**Ví dụ Minh họa:**

* **Input (Phẳng):** (VP (PP (P 在) (NP (NR 北京))) (VV 工作) (AS 了) (QP (CD 三) (M 年)))  
  * *Nghĩa:* Tại Bắc Kinh \- làm việc \- rồi \- ba năm.  
* **Xử lý:**  
  * Head \= (VV 工作).  
  * Left \= \[PP(在 北京)\].  
  * Right \= \`\`.  
* **Output (Phân tầng):**  
  (VP  
    (PP (P 在) (NP (NR 北京)))      \<-- Semantic Chunk 1: Trạng ngữ địa điểm  
    (@VP  
      (VV 工作)                     \<-- Head: Động từ chính  
      (@VP  
        (AS 了)                     \<-- Semantic Chunk 2: Trợ từ thời thái  
        (QP (CD 三) (M 年)))))      \<-- Semantic Chunk 3: Bổ ngữ thời lượng

* **Lợi ích:** Cấu trúc phân tầng này cho phép áp dụng luật dịch: "Nếu node con trái là PP chỉ địa điểm $\\rightarrow$ Đảo ra sau node con phải". Kết quả tiếng Việt: "Làm việc \[rồi\]\[ba năm\]".

## ---

**3\. Tích hợp Thực thể Định danh (NER Integration)**

Việc tích hợp NER (Ontonotes) vào cây Constituency là bước quan trọng để bảo toàn các đơn vị ngữ nghĩa không thể tách rời (như tên riêng, tên tổ chức) và xử lý các từ vựng OOV (Out-of-Vocabulary).15

### **3.1. Giải quyết Xung đột Ranh giới (Crossing Brackets)**

Mâu thuẫn xảy ra khi ranh giới của một thực thể NER cắt ngang ranh giới của các constituents trong cây cú pháp (ví dụ: NER nhận diện "Chủ tịch Hồ Chí Minh" là một PERSON, nhưng Parser tách "Chủ tịch" vào một NP riêng và "Hồ Chí Minh" vào một NP khác).17  
**Chiến lược Ưu tiên Thực thể (Entity-First Strategy):**  
Chúng ta coi NER là nguồn chân lý cao hơn về mặt ngữ nghĩa so với Parser cú pháp. Quy tắc xử lý như sau:

1. **Chiếu (Mapping):** Duyệt qua tất cả các span của NER. Kiểm tra xem có node nào trong cây CON khớp chính xác (Exact Match) với span này không.  
   * Nếu có: Gán nhãn ngữ nghĩa vào node đó (ví dụ: NP $\\rightarrow$ NP-PERSON).  
2. **Hợp nhất (Merge):** Nếu xảy ra xung đột (Crossing):  
   * Tìm **Lowest Common Ancestor (LCA)** của các token trong NER span.  
   * Thực hiện **Flattening**: Xóa bỏ các cấu trúc con bên dưới LCA nằm trong phạm vi NER span.  
   * Tạo một node mới (ví dụ NP-ENT) bao trùm toàn bộ các token của thực thể.  
   * *Ví dụ:* Cây (NP (NN Chủ tịch) (NP (NR Hồ) (NR Chí) (NR Minh))). NER span \= "Chủ tịch Hồ Chí Minh". $\\rightarrow$ Gộp thành (NP-PERSON Chủ tịch Hồ Chí Minh).

### **3.2. Cơ chế Semantic Tagging và Dịch OOV (Hán-Việt)**

Một lợi thế tuyệt đối của cặp ngôn ngữ Trung \- Việt là hệ thống từ Hán-Việt. Hầu hết các từ OOV (tên người, địa danh lạ) đều có thể dịch thông qua âm Hán-Việt thay vì cần từ điển dịch máy thống kê.19  
**Quy trình Xử lý OOV dựa trên NER:**

1. **Phát hiện:** Node có nhãn NER (PERSON, ORG, LOC) nhưng không tìm thấy trong từ điển dịch thuật chính.  
2. **Phân rã:** Tách chuỗi ký tự Trung văn thành từng char đơn lẻ.  
3. **Tra cứu Hán-Việt:** Sử dụng bảng mapping Char-to-SinoVietnamese.  
   * 习 $\\rightarrow$ Tập, 近 $\\rightarrow$ Cận, 平 $\\rightarrow$ Bình.  
4. **Tái tổ hợp:** Ghép lại thành "Tập Cận Bình".  
5. **Xử lý Tổ chức (ORG) đặc biệt:**  
   * Các thực thể ORG thường chứa từ khóa chức năng (Suffix) như 公司 (Công ty), 大学 (Đại học), 银行 (Ngân hàng).  
   * **Rule:** Tách Suffix ra khỏi Proper Name.  
   * Dịch Suffix theo từ điển (Vị trí đầu), Dịch Proper Name theo Hán-Việt (Vị trí sau).  
   * *Ví dụ:* (ORG (NR 复旦) (NN 大学)) (Phục Đán \- Đại học) $\\rightarrow$ Tiếng Việt: "Đại học Phục Đán".

## ---

**4\. Quy luật Tách và Đảo cụm từ (Splitting & Reordering Rules)**

Đây là "trái tim" của engine dịch thuật. Các quy tắc này biến đổi cấu trúc cây tiếng Trung (Source Tree) thành cấu trúc cây tiếng Việt (Target Tree) tương đương trước khi sinh từ.21

### **4.1. Demonstratives (Đại từ chỉ định)**

Tiếng Trung đặt đại từ chỉ định (这/này, 那/kia) ở đầu cụm danh từ, trong khi tiếng Việt đặt ở cuối.23

* **Cấu trúc Trung:** Demonstrative (DT) \+ Number (CD) \+ Classifier (M) \+ Noun (NN)  
  * *Ví dụ:* 这 (DT) 三 (CD) 本 (M) 书 (NN) (Này ba cuốn sách).  
* **Cấu trúc Việt:** Number \+ Classifier \+ Noun \+ Demonstrative  
  * *Mục tiêu:* Ba cuốn sách này.

**Quy tắc Chuyển đổi (Transformation Rule):**

1. **Match:** Node NP chứa con DT (hoặc DP) ở vị trí đầu tiên.  
2. **Action:**  
   * Dịch CD, M, NN tại chỗ.  
   * Di chuyển DT xuống vị trí con cuối cùng bên phải của NP.  
   * Map từ vựng: 这 $\\rightarrow$ này, 那 $\\rightarrow$ kia/đó.  
3. **Xử lý ẩn số "Một":** Trong tiếng Trung, 这 本 书 (Này cuốn sách) ngầm hiểu là "một".  
   * *Logic:* Nếu NP có DT và M nhưng thiếu CD $\\rightarrow$ Chèn node (CD một) vào trước M trong tiếng Việt nếu cần thiết, hoặc dịch thành "Cuốn sách này" (Classifier đóng vai trò mạo từ).

### **4.2. A-not-A Questions (Câu hỏi Chính phản)**

Cấu trúc V \+ 不 \+ V là đặc trưng tiếng Trung, cần chuyển thành cấu trúc khung "Có... không" của tiếng Việt.25

* **Case 1: Động từ đơn (Monosyllabic)**  
  * *Input:* (VP (VNV (VV 去) (AD 不) (VV 去))) (Đi không đi?)  
  * *Rule:*  
    1. Nhận diện node VNV.  
    2. Lấy động từ gốc $V$ (去).  
    3. Sinh chuỗi: **"có"** \+ $Trans(V)$ \+ **"không"**.  
  * *Output:* "Có đi không?"  
* **Case 2: Động từ ghép (Disyllabic \- AB)**  
  * *Input:* 喜 不 喜欢 (Thích không thích \- Xi bu Xihuan).  
  * *Phân tích:* HanLP thường parse thành (VNV (VV 喜) (AD 不) (VV 喜欢)).  
  * *Rule:*  
    1. Phát hiện mẫu A \+ bu \+ AB.  
    2. Lấy $V\_{full}$ là node con thứ 3 (喜欢).  
    3. Sinh chuỗi: **"có"** \+ $Trans(V\_{full})$ \+ **"không"**.  
  * *Output:* "Có thích không?"  
* **Case 3: Câu hỏi trong câu (Scope Handling)**  
  * *Input:* 你 明天 来 不 来? (Bạn ngày mai lai bất lai?)  
  * *Rule:* Đặt từ "Có" trước động từ chính, và đẩy từ "không" về **cuối câu** (hoặc cuối mệnh đề IP).  
  * *Output:* "Ngày mai bạn **có** đến **không**?" (Thay vì "Bạn ngày mai đến không đến").

### **4.3. Aspect Markers (Trợ từ động thái)**

Sự khác biệt về vị trí của các trợ từ thời thể (了, 着, 过) là rất lớn.21

| Trợ từ (CN) | Vị trí (CN) | Chức năng | Dịch & Vị trí (VN) | Quy tắc Chuyển đổi |
| :---- | :---- | :---- | :---- | :---- |
| **了 (le)** | Sau Động từ (V+le) | Hoàn thành (Perfective) | **đã** \+ V | **Move-Front:** Đưa lên trước V. |
| **了 (le)** | Cuối câu (SP) | Thay đổi trạng thái | ... **rồi** | Giữ nguyên vị trí cuối. |
| **着 (zhe)** | Sau Động từ | Tiếp diễn (Continuous) | **đang** \+ V | **Move-Front:** Đưa lên trước V. |
| **过 (guo)** | Sau Động từ | Trải nghiệm (Experiential) | **đã từng** \+ V | **Move-Front:** Đưa lên trước V. |

**Chi tiết thuật toán (V \+ Le):**

1. **Match:** Node VP có con là (AS/u 了/着/过).  
2. **Action:**  
   * Tách node AS.  
   * Tạo node mới (ADV đã/đang/từng).  
   * Chèn ADV vào vị trí **anh chị em (sibling) ngay bên trái** của Động từ chính (VV).  
   * Xóa node AS cũ.  
   * *Ví dụ:* (VP (VV 吃) (AS 了)) $\\rightarrow$ (VP (ADV đã) (VV ăn)).

### **4.4. Modifier-Head (Định ngữ \- Trung tâm ngữ)**

Đây là quy tắc đảo ngược kinh điển nhất: Tiếng Trung là "Bổ ngữ \+ Đích" (Left-branching), Tiếng Việt là "Đích \+ Bổ ngữ" (Right-branching).22

* **Cấu trúc 1: Sở hữu cách (DE \- 的)**  
  * *Input:* (NP (DNP (NP (NN 老师)) (DEG 的)) (NP (NN 书))) (Thầy giáo đích sách).  
  * *Target:* "Sách (của) thầy giáo".  
  * *Rule:* Đảo vị trí hai cụm NP con. Thay DEG bằng "của".  
* **Cấu trúc 2: Mệnh đề quan hệ (Relative Clause)**  
  * *Input:* (NP (CP (IP (NP (PN 我)) (VP (VV 买))) (DEC 的)) (NP (NN 书))) (Tôi mua đích sách).  
  * *Target:* "Sách (mà) tôi mua".  
  * *Rule:* Đảo vị trí CP và NP trung tâm. Thay DEC bằng "mà" (hoặc rỗng).  
* **Cấu trúc 3: Định ngữ Đa tầng (Multi-layered Modifiers)**  
  * *Input:* \[\[\[Hạnh phúc\] của\]\[gia đình\] tôi\] (Tiếng Trung: 我 (của) 家庭 (của) 幸福 \- Wo de jiating de xingfu).  
  * *Chiến lược Đệ quy (Recursive Strategy):*  
    1. Hệ thống xử lý từ dưới lên (Bottom-up).  
    2. Tầng 1 (Sâu nhất): 我 的 家庭 $\\rightarrow$ Đảo thành Gia đình (của) tôi.  
    3. Tầng 2: \[Gia đình của tôi\] 的 幸福 $\\rightarrow$ Đảo thành Hạnh phúc (của) \[Gia đình của tôi\].  
  * *Kết quả:* "Hạnh phúc của gia đình tôi". (Trùng khớp tự nhiên với tiếng Việt).

### **4.5. Prepositional Phrases (Cụm giới từ)**

Trạng ngữ chỉ địa điểm/công cụ trong tiếng Trung thường đứng trước động từ (Pre-verbal), trong khi tiếng Việt ưu tiên đứng sau (Post-verbal).30

* **Input:** 我 \[在 学校\] 学习 (Tôi \[tại trường\] học).  
* **Target:** Tôi học \[ở trường\].

**Quy tắc Di chuyển (Movement Rule):**

1. **Trigger:** Node VP chứa con PP. Kiểm tra Giới từ đầu (Head P) của PP.  
2. **Condition:** Nếu $P$ thuộc nhóm {在 (tại), 于 (ở), 往 (về), 向 (hướng về), 自 (từ)}: Kích hoạt luật đảo.  
   * *Ngoại lệ:* Các giới từ như 对于 (đối với), 关于 (về) thường đứng đầu câu hoặc giữ nguyên vị trí trước V để nhấn mạnh chủ đề, không cần đảo.  
3. **Action:**  
   * Cắt (Detach) node PP.  
   * Gắn (Attach) node PP vào sau node Động từ chính (VV) hoặc sau Tân ngữ (OBJ) tùy thuộc vào loại động từ.  
   * *Heuristic:* Với động từ chuyển động (đi, đến), PP dính chặt sau V. Với động từ hành động (ăn, học), PP thường đứng sau Tân ngữ (Học tiếng Việt *ở Hà Nội*).

## ---

**5\. Cơ chế Disambiguation dựa trên Quan hệ Phụ thuộc**

Dịch từ vựng chính xác đòi hỏi phải nhìn vào "bạn đồng hành" của từ đó. Chúng ta xây dựng **Ma trận Khử mơ hồ (WSD Matrix)** dựa trên kết quả Dependency Parsing của HanLP.32

### **5.1. Động từ \+ Tân ngữ (Verb-Object)**

Quan hệ dobj là yếu tố quyết định nghĩa của động từ đa nghĩa (Light Verbs). Ví dụ động từ 打 (Dả) có hàng chục nghĩa.

| Động từ (Head) | Tân ngữ (Dep dobj) | Nhóm Ngữ nghĩa (Semantic Class) | Dịch sang Tiếng Việt | Ví dụ Minh họa |
| :---- | :---- | :---- | :---- | :---- |
| **打 (dǎ)** | 电话 (điện thoại) | Communication | **gọi** | 打电话 $\\rightarrow$ Gọi điện |
|  | 球 (bóng), 篮球 | Sport | **chơi / đánh** | 打篮球 $\\rightarrow$ Chơi bóng rổ |
|  | 人 (người) | Animate | **đánh** | 打人 $\\rightarrow$ Đánh người |
|  | 毛衣 (áo len) | Clothing/Fabric | **đan** | 打毛衣 $\\rightarrow$ Đan áo len |
|  | 水 (nước), 饭 (cơm) | Resource | **lấy / múc** | 打饭 $\\rightarrow$ Lấy cơm |
| **开 (kāi)** | 车 (xe) | Vehicle | **lái** | 开车 $\\rightarrow$ Lái xe |
|  | 会 (hội) | Event | **họp / tổ chức** | 开会 $\\rightarrow$ Họp |
|  | 门 (cửa) | Physical Object | **mở** | 开门 $\\rightarrow$ Mở cửa |
|  | 玩笑 (trò đùa) | Abstract | **đùa** | 开玩笑 $\\rightarrow$ Đùa |

**Giải thuật Lookup:** Truy vấn cặp (Lemma\_V, Lemma\_O). Nếu không khớp chính xác, truy vấn (Lemma\_V, SemanticClass\_O) (ví dụ dùng WordNet hoặc Embedding Cluster để biết "bóng đá" thuộc nhóm Sport).

### **5.2. Lượng từ \+ Danh từ (Classifier-Noun)**

Tiếng Việt phân biệt kỹ lưỡng loại từ (con, cái, chiếc, quả, vị...) trong khi tiếng Trung thường dùng 个 (gè) chung chung.34

* **Dependency:** clf (classifier) hoặc quantmod.  
* **Logic:**  
  * Nếu Lượng từ tiếng Trung là 个, 只, 位... $\\rightarrow$ Bỏ qua nghĩa gốc.  
  * Tra cứu Danh từ tiếng Việt trong từ điển để lấy **Lượng từ cố hữu (Default Classifier)**.  
  * *Ví dụ:* 三 个 老师 (Tam cá lão sư). Tra từ điển: "Giáo viên" $\\rightarrow$ Lượng từ tôn trọng là "người" hoặc "vị". $\\rightarrow$ "Ba vị giáo viên".  
  * *Ví dụ:* 一 个 苹果 (Nhất cá bình quả). Tra từ điển: "Táo" $\\rightarrow$ Lượng từ "quả/trái". $\\rightarrow$ "Một quả táo".

### **5.3. Động từ \+ Bổ ngữ (Verb-Complements)**

Các cấu trúc bổ ngữ kết quả/xu hướng (Resultative/Directional) thường được gộp thành một động từ ghép trong tiếng Việt.35 HanLP gán nhãn cmp hoặc rcomp.

* **V-R (Kết quả):**  
  * 看 (nhìn) \+ 见 (kiến \- thấy) $\\rightarrow$ Dịch gộp: **"thấy"** hoặc **"nhìn thấy"**.  
  * 听 (nghe) \+ 懂 (hiểu) $\\rightarrow$ Dịch gộp: **"hiểu"** hoặc **"nghe hiểu"**.  
  * 做 (làm) \+ 完 (xong) $\\rightarrow$ Dịch: **"làm xong"**.  
* **V-D (Xu hướng):**  
  * 跑 (chạy) \+ 进 (vào) \+ 来 (lai \- tới) $\\rightarrow$ **"chạy vào"**. (Bỏ qua hoặc giảm nhẹ từ "lai" nếu không cần thiết nhấn mạnh hướng về phía người nói).

### **5.4. Giới từ (Coverb) \+ Động từ**

Cấu trúc Coverb \+ NP \+ V ảnh hưởng đến thể (Voice) của câu.

* **被 (bèi \- Bị/Được):** Đánh dấu thể bị động.  
  * *Logic:* Nếu V mang nghĩa tiêu cực (đánh, mắng, phạt) $\\rightarrow$ Dịch bèi là **"bị"**.  
  * Nếu V mang nghĩa tích cực (khen, thưởng, chọn) $\\rightarrow$ Dịch bèi là **"được"**.  
* **把 (bǎ \- Đem/Lấy):** Câu chữ Bả dùng để nhấn mạnh tác động lên tân ngữ.  
  * *Input:* 把 书 看 完 (Bả thư khán hoàn).  
  * *Rule:* Tiếng Việt không có cấu trúc tương đương hoàn toàn. Thường chuyển về SVO thường hoặc dùng từ "đem/lấy".  
  * *Trans:* "Đọc xong sách" (Natural) hoặc "Đem sách đọc xong" (Emphasis).

### **5.5. Động từ \+ Lượng từ động lượng (V-Q)**

* **Pattern:** Verb \+ Num \+ Verbal-Classifier (VD: 看一眼, 去一趟).  
* **Mapping:**  
  * 一趟 (yī tàng \- chuyến) $\\rightarrow$ "một chuyến" (Go a trip).  
  * 一下 (yī xià \- nhất hạ) $\\rightarrow$ "một chút / một cái / thử". (VD: Kàn yī xià $\\rightarrow$ "Xem thử" hoặc "Nhìn một cái").  
  * 一遍 (yī biàn \- nhất biến) $\\rightarrow$ "một lần / một lượt".

## ---

**6\. Lộ trình Triển khai (Implementation Roadmap)**

### **Giai đoạn 1: Xây dựng Hạ tầng & Parsing (Tuần 1-4)**

* Cài đặt HanLP MTL (CLOSE\_TOK\_POS\_NER\_SRL\_DEP\_SDP\_CON\_ELECTRA\_SMALL\_ZH).  
* Xây dựng module **Tree Wrapper**: Class Python để chứa node cây, tích hợp thông tin NER và Dependency vào node tương ứng.  
* Triển khai thuật toán **Head-Driven Binarization** và kiểm thử trên tập dữ liệu mẫu CTB.

### **Giai đoạn 2: Tích hợp Dữ liệu & NER (Tuần 5-8)**

* Xây dựng từ điển **Core Dictionary** (Trung-Việt) và **Classifier Mapping**.  
* Triển khai module **Sino-Vietnamese Converter**: Tự động chuyển đổi tên riêng/địa danh OOV.  
* Giải quyết bài toán **Crossing Brackets** giữa NER và Tree.

### **Giai đoạn 3: Phát triển Engine Luật (Tuần 9-14)**

* Code các class TransformationRule:  
  * NPRestructuringRule: Xử lý DE, Demonstratives.  
  * VPRestructuringRule: Xử lý PP movement, Aspect.  
  * QuestionTransformation: Xử lý A-not-A.  
* Xây dựng hệ thống Unit Test với các cặp câu ví dụ (Golden Standard) để đảm bảo luật chạy đúng đệ quy.

### **Giai đoạn 4: Disambiguation & Tinh chỉnh (Tuần 15-20)**

* Tích hợp ma trận WSD vào bước sinh từ.  
* Chạy thử nghiệm trên tập dữ liệu thực tế (News, Technical Docs).  
* Phân tích lỗi (Error Analysis) và bổ sung các luật ngoại lệ (Exception Handling).

---

Tài liệu này cung cấp nền tảng kỹ thuật chi tiết để đội ngũ phát triển (Dev) có thể bắt tay vào code ngay các module xử lý cây và luật ngôn ngữ. Sự kết hợp giữa sức mạnh phân tích của HanLP MTL và độ chính xác của luật ngôn ngữ học đối chiếu sẽ tạo ra một engine dịch thuật chất lượng cao cho cặp ngôn ngữ Trung \- Việt.

#### **Works cited**

1. hanlp \- PyPI, accessed February 7, 2026, [https://pypi.org/project/hanlp/](https://pypi.org/project/hanlp/)  
2. Source code for hanlp.components.mtl.tasks.constituency \- Hankcs, accessed February 7, 2026, [https://hanlp.hankcs.com/docs/\_modules/hanlp/components/mtl/tasks/constituency.html](https://hanlp.hankcs.com/docs/_modules/hanlp/components/mtl/tasks/constituency.html)  
3. The Segmentation Guidelines for the Penn Chinese Treebank (3.0) \- HanLP, accessed February 7, 2026, [https://hanlp.hankcs.com/docs/annotations/tok/ctb.html](https://hanlp.hankcs.com/docs/annotations/tok/ctb.html)  
4. The Part-Of-Speech Tagging Guidelines for the Penn Chinese Treebank (3.0) Fei Xia October 17, 2000 \- LDC Catalog, accessed February 7, 2026, [https://catalog.ldc.upenn.edu/docs/LDC2010T07/ctb-posguide.pdf](https://catalog.ldc.upenn.edu/docs/LDC2010T07/ctb-posguide.pdf)  
5. OntoNotes Release 5.0 \- LDC Catalog, accessed February 7, 2026, [https://catalog.ldc.upenn.edu/docs/LDC2013T19/OntoNotes-Release-5.0.pdf](https://catalog.ldc.upenn.edu/docs/LDC2013T19/OntoNotes-Release-5.0.pdf)  
6. Fast and Accurate Neural CRF Constituency Parsing \- IJCAI, accessed February 7, 2026, [https://www.ijcai.org/proceedings/2020/0560.pdf](https://www.ijcai.org/proceedings/2020/0560.pdf)  
7. High-order Joint Constituency and Dependency Parsing \- ACL Anthology, accessed February 7, 2026, [https://aclanthology.org/2024.lrec-main.713.pdf](https://aclanthology.org/2024.lrec-main.713.pdf)  
8. Dependency Parsing \- Stanford University, accessed February 7, 2026, [https://web.stanford.edu/\~jurafsky/slp3/19.pdf](https://web.stanford.edu/~jurafsky/slp3/19.pdf)  
9. Dependency Parsing — HanLP Documentation \- Hankcs, accessed February 7, 2026, [https://hanlp.hankcs.com/docs/annotations/dep/index.html](https://hanlp.hankcs.com/docs/annotations/dep/index.html)  
10. Straight to the Tree: Constituency Parsing with Neural Syntactic Distance \- ACL Anthology, accessed February 7, 2026, [https://aclanthology.org/P18-1108.pdf](https://aclanthology.org/P18-1108.pdf)  
11. Parsing Noun Phrases in the Penn Treebank \- ACL Anthology, accessed February 7, 2026, [https://aclanthology.org/J11-4006.pdf](https://aclanthology.org/J11-4006.pdf)  
12. Binarized Forest to String Translation \- ACL Anthology, accessed February 7, 2026, [https://aclanthology.org/P11-1084.pdf](https://aclanthology.org/P11-1084.pdf)  
13. Multi-view Chinese Treebanking \- Yue Zhang, accessed February 7, 2026, [https://frcchang.github.io/pub/coling14.likun.pdf](https://frcchang.github.io/pub/coling14.likun.pdf)  
14. DISCRIMINATIVE LEARNING APPROACHES FOR ... \- Yue Zhang, accessed February 7, 2026, [https://frcchang.github.io/pub/thesis.pdf](https://frcchang.github.io/pub/thesis.pdf)  
15. Bottom-Up Constituency Parsing and Nested Named Entity Recognition with Pointer Networks \- ACL Anthology, accessed February 7, 2026, [https://aclanthology.org/2022.acl-long.171.pdf](https://aclanthology.org/2022.acl-long.171.pdf)  
16. (PDF) Joint Parsing and Named Entity Recognition. \- ResearchGate, accessed February 7, 2026, [https://www.researchgate.net/publication/220816778\_Joint\_Parsing\_and\_Named\_Entity\_Recognition](https://www.researchgate.net/publication/220816778_Joint_Parsing_and_Named_Entity_Recognition)  
17. Context-Free Grammars and Constituency Parsing \- Stanford University, accessed February 7, 2026, [https://web.stanford.edu/\~jurafsky/slp3/18.pdf](https://web.stanford.edu/~jurafsky/slp3/18.pdf)  
18. Constituency Parsing \- Stanford University, accessed February 7, 2026, [https://web.stanford.edu/\~jurafsky/slp3/old\_sep21/13.pdf](https://web.stanford.edu/~jurafsky/slp3/old_sep21/13.pdf)  
19. Handling organization name unknown word in Chinese-Vietnamese machine translation, accessed February 7, 2026, [https://www.researchgate.net/publication/261477805\_Handling\_organization\_name\_unknown\_word\_in\_Chinese-Vietnamese\_machine\_translation](https://www.researchgate.net/publication/261477805_Handling_organization_name_unknown_word_in_Chinese-Vietnamese_machine_translation)  
20. A Character Level Based and Word Level Based Approach for Chinese-Vietnamese Machine Translation \- Semantic Scholar, accessed February 7, 2026, [https://pdfs.semanticscholar.org/f469/da6c41a2a9dcff0bdfc144e826b88928fcd8.pdf](https://pdfs.semanticscholar.org/f469/da6c41a2a9dcff0bdfc144e826b88928fcd8.pdf)  
21. Chinese grammar \- Wikipedia, accessed February 7, 2026, [https://en.wikipedia.org/wiki/Chinese\_grammar](https://en.wikipedia.org/wiki/Chinese_grammar)  
22. Chinese Syntactic Reordering for Statistical Machine Translation \- ACL Anthology, accessed February 7, 2026, [https://aclanthology.org/D07-1077.pdf](https://aclanthology.org/D07-1077.pdf)  
23. Vietnamese grammar \- Wikipedia, accessed February 7, 2026, [https://en.wikipedia.org/wiki/Vietnamese\_grammar](https://en.wikipedia.org/wiki/Vietnamese_grammar)  
24. Language Guidelines – Vietnamese \- Unbabel Community Support, accessed February 7, 2026, [https://help.unbabel.com/hc/en-us/articles/360022945614-Language-Guidelines-Vietnamese](https://help.unbabel.com/hc/en-us/articles/360022945614-Language-Guidelines-Vietnamese)  
25. Focus AND BACKGROUND MARKING \- Institut für Linguistik, accessed February 7, 2026, [https://www.ling.uni-stuttgart.de/institut/ilg/dokumente/Hole-Dateien/Hole2004.pdf](https://www.ling.uni-stuttgart.de/institut/ilg/dokumente/Hole-Dateien/Hole2004.pdf)  
26. Câu hỏi chính phản trong tiếng Trung: Cấu trúc, cách dùng\!, accessed February 7, 2026, [https://prepedu.com/vi/blog/cau-hoi-chinh-phan-trong-tieng-trung](https://prepedu.com/vi/blog/cau-hoi-chinh-phan-trong-tieng-trung)  
27. A Character Level Based and Word Level Based Approach for Chinese-Vietnamese Machine Translation \- NIH, accessed February 7, 2026, [https://pmc.ncbi.nlm.nih.gov/articles/PMC4942671/](https://pmc.ncbi.nlm.nih.gov/articles/PMC4942671/)  
28. The 11th Workshop on Asian Language Resources \- ACL Anthology, accessed February 7, 2026, [https://aclanthology.org/W13-43.pdf](https://aclanthology.org/W13-43.pdf)  
29. A Structural Analysis of Noun Phrases in English and Vietnamese: A Comparative Study \- Theory and Practice in Language Studies, accessed February 7, 2026, [https://tpls.academypublication.com/index.php/tpls/article/download/8149/6657/24913](https://tpls.academypublication.com/index.php/tpls/article/download/8149/6657/24913)  
30. (PDF) Preordering for Chinese-Vietnamese Statistical Machine Translation \- ResearchGate, accessed February 7, 2026, [https://www.researchgate.net/publication/330808742\_Preordering\_for\_Chinese-Vietnamese\_Statistical\_Machine\_Translation](https://www.researchgate.net/publication/330808742_Preordering_for_Chinese-Vietnamese_Statistical_Machine_Translation)  
31. (PDF) Dependency-based pre-ordering of preposition phrases in Chinese-Vietnamese machine translation \- ResearchGate, accessed February 7, 2026, [https://www.researchgate.net/publication/323411369\_Dependency-based\_pre-ordering\_of\_preposition\_phrases\_in\_Chinese-Vietnamese\_machine\_translation](https://www.researchgate.net/publication/323411369_Dependency-based_pre-ordering_of_preposition_phrases_in_Chinese-Vietnamese_machine_translation)  
32. Graph-Based Chinese Word Sense Disambiguation with Multi-Knowledge Integration \- Macquarie University, accessed February 7, 2026, [https://research-management.mq.edu.au/ws/portalfiles/portal/121564472/121518439.pdf](https://research-management.mq.edu.au/ws/portalfiles/portal/121564472/121518439.pdf)  
33. Word Sense Disambiguation for 158 Languages using Word Embeddings Only, accessed February 7, 2026, [https://www.inf.uni-hamburg.de/en/inst/ab/lt/publications/2020-logachevaetal-lrec20-158wsd.pdf](https://www.inf.uni-hamburg.de/en/inst/ab/lt/publications/2020-logachevaetal-lrec20-158wsd.pdf)  
34. An Investigation of Vietnamese Classifiers in English – Vietnamese Translation Introduction \- International Journal of TESOL & Education, accessed February 7, 2026, [https://www.i-jte.org/index.php/journal/article/download/278/84/3134](https://www.i-jte.org/index.php/journal/article/download/278/84/3134)  
35. Stanford Dependencies Chinese — HanLP Documentation, accessed February 7, 2026, [https://hanlp.hankcs.com/docs/annotations/dep/sd\_zh.html](https://hanlp.hankcs.com/docs/annotations/dep/sd_zh.html)  
36. Chinese Word Sense Disambiguation Based on Lexical Semantic Ontology \- COLIPS, accessed February 7, 2026, [https://www.colips.org/journals/volume18/JCLC\_2008\_V18\_N1\_02.pdf](https://www.colips.org/journals/volume18/JCLC_2008_V18_N1_02.pdf)