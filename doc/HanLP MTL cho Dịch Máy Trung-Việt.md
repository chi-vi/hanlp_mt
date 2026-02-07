# **Báo cáo Nghiên cứu Chuyên sâu: Xây dựng Cơ sở Dữ liệu Cú pháp và Chiến lược Sắp xếp lại Trật tự Từ cho Hệ thống Dịch máy Trung-Việt sử dụng HanLP MTL**

## **Tóm tắt Điều hành**

Báo cáo này cung cấp một phân tích kỹ thuật toàn diện nhằm thiết kế kiến trúc xử lý ngôn ngữ tự nhiên (NLP) cho hệ thống dịch máy Trung-Việt, dựa trên nền tảng thư viện HanLP và mô hình Đa nhiệm (Multi-Task Learning \- MTL). Mục tiêu cốt lõi là giải quyết vấn đề bất đồng cấu trúc cú pháp giữa tiếng Trung và tiếng Việt thông qua phương pháp **Sắp xếp lại trật tự cú pháp (Syntactic Pre-ordering)**. Mặc dù cả hai ngôn ngữ đều thuộc loại hình đơn lập và có trật tự từ cơ bản là Chủ-Động-Tân (SVO), sự khác biệt sâu sắc trong cấu trúc nội bộ của Cụm danh từ (Noun Phrase), Cụm giới từ (Prepositional Phrase) và Mệnh đề quan hệ (Relative Clause) đòi hỏi một sự can thiệp cấu trúc trước khi dịch từ vựng.  
Dựa trên phân tích các tiêu chuẩn ngữ liệu và khả năng của HanLP, báo cáo đưa ra các khuyến nghị sau:

1. **Tác vụ tối thiểu (Minimal Tasks):** Hệ thống cần tích hợp bốn tác vụ: **Phân tách từ (Tokenization \- TOK)**, **Gán nhãn từ loại (POS Tagging)**, **Nhận dạng thực thể tên riêng (NER)**, và **Phân tích cú pháp thành phần (Constituency Parsing \- CON)**. Phân tích cú pháp phụ thuộc (Dependency Parsing \- DEP) mặc dù mạnh mẽ nhưng không cung cấp trực tiếp các "khối cụm từ" (phrasal constituents) cần thiết cho việc đảo vị trí khối như yêu cầu của người dùng, do đó CON là lựa chọn tối ưu hơn.  
2. **Lựa chọn Biến thể (Variant Selection):**  
   * **POS Tagging:** Bắt buộc sử dụng chuẩn **CTB (Penn Chinese Treebank)**. Đây là tiêu chuẩn duy nhất tương thích hoàn toàn với các mô hình phân tích cú pháp hiện đại và cung cấp các nhãn chức năng quan trọng (như LC cho từ chỉ phương vị, DEC/DEG cho trợ từ kết cấu) để kích hoạt các luật chuyển đổi sang tiếng Việt.  
   * **NER:** Khuyến nghị sử dụng chuẩn **OntoNotes 5.0**. Với 18 loại thực thể (bao gồm số đếm, thời gian, phần trăm), nó vượt trội hơn chuẩn MSRA (chỉ có 3 loại) trong việc bảo vệ các "định danh cứng" (rigid designators) khỏi bị xáo trộn trật tự trong quá trình tái cấu trúc cây.  
   * **Parsing:** Sử dụng chuẩn **CTB** cho phân tích cú pháp thành phần để đảm bảo tính nhất quán với nhãn từ loại.

Báo cáo sẽ đi sâu vào chi tiết kỹ thuật của từng lựa chọn, so sánh các bộ dữ liệu, và mô tả thuật toán duyệt cây để thực hiện "tìm nghĩa và đảo vị trí" như yêu cầu.

## ---

**1\. Tổng quan và Cơ sở Lý thuyết: Tại sao cần Phân tích Cú pháp cho Dịch máy Trung-Việt?**

### **1.1 Thách thức Ngôn ngữ học trong Cặp ngôn ngữ Trung-Việt**

Trong lĩnh vực dịch máy (Machine Translation), cặp ngôn ngữ Trung-Việt thường được xem là "gần gũi" do sự tương đồng về loại hình ngôn ngữ (cả hai đều là ngôn ngữ đơn lập, không biến hình) và chia sẻ một lượng lớn từ vựng Hán-Việt. Tuy nhiên, sự tương đồng bề mặt này thường dẫn đến những sai lầm nghiêm trọng trong các hệ thống dịch dựa trên từ vựng đơn thuần. Sự khác biệt cốt lõi nằm ở **tham số hướng đầu (head-directionality)** trong các cụm từ thấp hơn cấp độ câu.  
Trong ngôn ngữ học cấu trúc, một cụm từ bao gồm một "trung tâm" (head) và các "bổ tố" (modifiers). Tiếng Việt là ngôn ngữ **Head-Initial** (Trung tâm đứng trước) điển hình trong cụm danh từ, trong khi tiếng Trung là ngôn ngữ **Head-Final** (Trung tâm đứng sau).

* **Cấu trúc Cụm Danh từ (NP):**  
  * *Tiếng Trung:* \+ (de) \+. Ví dụ: "hóng sè de chē" (Màu đỏ của xe).  
  * *Tiếng Việt:* \+. Ví dụ: "xe màu đỏ".  
  * *Hệ quả:* Máy dịch cần phải đảo ngược toàn bộ trật tự của cụm danh từ. Nếu cụm danh từ này phức tạp (ví dụ: chứa một mệnh đề quan hệ), việc đảo từ vựng đơn thuần là không thể; hệ thống cần nhận diện được ranh giới của cả khối cụm từ để đảo nguyên khối.  
* **Cấu trúc Cụm Phương vị (Localizer Phrase \- LCP):**  
  * *Tiếng Trung:* \+ \[Phương vị từ\]. Ví dụ: "zhuōzi shàng" (Bàn trên).  
  * *Tiếng Việt:* \[Giới từ\] \+. Ví dụ: "Trên bàn".  
  * *Hệ quả:* Đây là sự chuyển đổi từ cấu trúc "Hậu giới từ" (Postposition) sang "Tiền giới từ" (Preposition).

Người dùng đã xác định chính xác nhu cầu: "tạo cây ngữ pháp gồm nhiều bậc cụm từ... rồi đảo lại vị trí". Đây chính là phương pháp **Syntactic Pre-ordering** (Sắp xếp trước dựa trên cú pháp), một kỹ thuật đã được chứng minh là cải thiện đáng kể chất lượng dịch máy thống kê và nơ-ron cho các cặp ngôn ngữ có trật tự từ khác biệt.1

### **1.2 Vai trò của HanLP Multi-Task Learning (MTL)**

HanLP phiên bản 2.1 trở lên giới thiệu kiến trúc Multi-Task Learning (MTL). Đây là một bước tiến quan trọng so với các mô hình đường ống (pipeline) truyền thống. Trong mô hình đường ống cũ, lỗi lan truyền (error propagation) là vấn đề lớn: nếu bước phân tách từ sai, bước POS sẽ sai, dẫn đến cây cú pháp sai hoàn toàn.  
Mô hình MTL giải quyết vấn đề này bằng cách sử dụng một bộ mã hóa chia sẻ (Shared Encoder), thường là các mô hình ngôn ngữ lớn như BERT hoặc ELECTRA.4 Bộ mã hóa này học các đặc trưng ngữ cảnh phong phú từ văn bản đầu vào, sau đó chia sẻ các biểu diễn vector này cho các bộ giải mã (decoders) riêng biệt cho từng tác vụ (POS, NER, Parsing).

* **Lợi ích cho bài toán của người dùng:** Khi thực hiện phân tích cú pháp để làm cơ sở cho dịch máy, độ chính xác là yếu tố sống còn. Việc sử dụng HanLP MTL giúp các tác vụ hỗ trợ lẫn nhau. Ví dụ, thông tin từ NER (biết "Bắc Kinh" là Địa danh) sẽ giúp bộ phân tích cú pháp không tách đôi từ này ra, và ngược lại, cấu trúc cú pháp giúp định hướng từ loại chính xác hơn.

## ---

**2\. Phân tích và Lựa chọn Các Tác vụ Tối thiểu (Minimum Task Selection)**

Người dùng đặt câu hỏi về các bước tối thiểu cần thiết: POS, NER, CON, hay DEP? Để xây dựng một "cây ngữ pháp nhiều bậc" phục vụ việc đảo trật tự từ và tra từ điển, chúng ta cần phân tích vai trò của từng thành phần.

### **2.1 Part-of-Speech Tagging (POS) \- Bắt buộc**

**Vai trò:** POS là nền tảng của mọi quy tắc ngữ pháp. Trong cây cú pháp, POS đóng vai trò là các "lá" (leaves) hoặc các nút tiền kết thúc (pre-terminals).  
**Tại sao cần thiết cho Dịch máy Trung-Việt:**  
Để tra từ điển chính xác, chúng ta cần biết từ loại. Tiếng Trung có hiện tượng "từ loại linh hoạt" rất phổ biến.

* Ví dụ từ: "gōng zuò" (công tác).  
  * Nếu POS là VV (Động từ): Dịch là "làm việc".  
  * Nếu POS là NN (Danh từ): Dịch là "công việc".  
    Hơn nữa, các quy tắc đảo trật tự dựa hoàn toàn vào nhãn POS. Làm sao máy biết phải đảo "zhuōzi shàng"? Nó cần biết "zhuōzi" là NN (Danh từ) và "shàng" là LC (Phương vị từ). Nếu không có nhãn POS LC, máy không thể kích hoạt luật chuyển đổi sang giới từ tiếng Việt.

### **2.2 Named Entity Recognition (NER) \- Bắt buộc**

**Vai trò:** Nhận diện và phân loại các thực thể tên riêng (Người, Tổ chức, Địa điểm, Số liệu...).  
**Tại sao cần thiết:** Đây là thành phần bảo vệ cấu trúc (Structure Protection). Một trong những lỗi lớn nhất của các hệ thống "Pre-ordering" là **đảo lộn nội bộ tên riêng**.

* Ví dụ: "New York University" (Đại học New York).  
* Nếu không có NER: Bộ phân tích cú pháp có thể nhìn thấy cấu trúc \+ \+. Nếu áp dụng luật đảo "Danh từ \+ Tính từ" của tiếng Việt một cách mù quáng, hệ thống có thể sinh ra "University York New" hoặc "York New University".  
* Nếu có NER: Hệ thống NER gắn nhãn cả cụm "New York University" là một thực thể ORG (Tổ chức). Trong quá trình xử lý cây, chúng ta coi nút ORG này là một **nút nguyên tử (atomic node)**. Thuật toán đảo trật tự sẽ bị "cấm" xâm nhập vào bên trong nút này. Toàn bộ cụm sẽ được dịch nguyên khối hoặc tra cứu từ điển chuyên ngành.

### **2.3 Constituency Parsing (CON) vs. Dependency Parsing (DEP) \- Lựa chọn CON**

Người dùng hỏi về cả hai, nhưng với mục tiêu "tạo cây ngữ pháp gồm nhiều bậc cụm từ", sự lựa chọn là rõ ràng.

#### **Tại sao chọn Constituency Parsing (CON)?**

Constituency Parsing (Phân tích cú pháp thành phần) chia câu thành các cấu trúc phân cấp lồng nhau: Cụm Danh từ (NP), Cụm Động từ (VP), Cụm Giới từ (PP), Mệnh đề (IP/S).

* **Sự phù hợp với mục tiêu:** Đầu ra của CON chính xác là "cây ngữ pháp nhiều bậc" mà người dùng mô tả.6 Nó nhóm các từ lại thành các khối (chunks).  
* **Cơ chế đảo trật tự:** Việc chuyển đổi cấu trúc Trung-Việt chủ yếu là việc hoán đổi vị trí của các khối này. Ví dụ: Để biến đổi cụm danh từ, ta chỉ cần hoán đổi vị trí của cây con bên trái và cây con bên phải của nút NP. Thao tác này trên cây Constituency rất trực quan và dễ lập trình đệ quy.8

#### **Tại sao KHÔNG chọn Dependency Parsing (DEP) cho mục tiêu này?**

Dependency Parsing (Phân tích cú pháp phụ thuộc) tạo ra các mối quan hệ nhị phân giữa các từ (ví dụ: từ A là chủ ngữ của từ B).10

* **Hạn chế:** DEP không tạo ra các nút cụm từ (phrasal nodes). Nó không cho bạn biết "đâu là điểm bắt đầu và kết thúc của cụm danh từ này". Để tìm được phạm vi của một cụm từ trong cây DEP, bạn phải thực hiện thuật toán tìm "tập hợp con cháu" (yield) của một nút, điều này phức tạp hơn và dễ lỗi hơn khi xử lý các cấu trúc không liên tục (non-projective).  
* **Ứng dụng:** DEP phù hợp hơn cho việc trích xuất quan hệ ngữ nghĩa (Ai làm gì?) hơn là tái cấu trúc trật tự từ cho dịch máy dựa trên luật (Rule-based reordering).

### **2.4 Kết luận về Tác vụ**

Bộ tác vụ tối thiểu và đủ để xây dựng cơ sở dữ liệu cho máy dịch là: **TOK \+ POS \+ NER \+ CON**.

## ---

**3\. Phân tích và Lựa chọn Biến thể (Variant Selection): "Cái nào hợp lý nhất?"**

Đây là phần quan trọng nhất để trả lời câu hỏi "chọn cái nào?" của người dùng. HanLP hỗ trợ nhiều chuẩn dữ liệu khác nhau (CTB, PKU, MSRA, OntoNotes), và việc chọn sai chuẩn sẽ dẫn đến sự không tương thích hoặc thiếu thông tin ngôn ngữ học cần thiết cho tiếng Việt.

### **3.1 Part-of-Speech (POS): Chọn CTB (Penn Chinese Treebank)**

Có ba lựa chọn chính: **CTB**, **PKU**, và **863**.  
Bảng so sánh dưới đây minh họa tại sao CTB là lựa chọn duy nhất phù hợp cho bài toán này.

| Đặc điểm | CTB (Penn Chinese Treebank) | PKU (Peking University) | 863 / NCC |
| :---- | :---- | :---- | :---- |
| **Mục đích thiết kế** | Phục vụ phân tích cú pháp (Parsing) và cấu trúc câu. | Phục vụ phân tách từ và từ điển học. | Phục vụ tổng hợp tiếng nói và xử lý nông. |
| **Độ mịn của nhãn chức năng** | **Rất cao**. Phân biệt rõ ràng các hư từ (function words). | Thấp hơn. Gộp nhiều hư từ vào các nhóm chung. | Trung bình. |
| **Xử lý "de" (的/地/得)** | Tách biệt DEC (bổ ngữ định danh/quan hệ) và DEG (sở hữu cách). | Gộp chung thành u (trợ từ). | Gộp chung. |
| **Xử lý phương vị từ** | Có nhãn riêng LC (Localizer). | Thường gộp vào danh từ chỉ nơi chốn (f, s). | Gộp vào danh từ. |
| **Tương thích Parsing** | **Tuyệt đối**. Hầu hết parser hiện đại được huấn luyện trên CTB. | Kém. Parser huấn luyện trên CTB sẽ hoạt động sai nếu input là PKU POS. | Kém. |

#### **Phân tích Chi tiết: Tại sao CTB thắng thế cho Dịch Trung-Việt?**

1. **Nhãn LC (Localizer):**  
   Tiếng Trung dùng phương vị từ đứng sau danh từ (Hậu giới từ) để chỉ vị trí, ví dụ: "zhuōzi **shàng**" (bàn **trên**). Tiếng Việt dùng giới từ đứng trước: "**trên** bàn".  
   * Với nhãn **CTB**: Từ "shàng" được gán nhãn LC. Thuật toán của bạn có thể viết luật đơn giản: Nếu gặp cấu trúc \[NP \+ LC\], hãy đảo ngược thành \[LC \+ NP\] và dịch LC như giới từ.  
   * Với nhãn **PKU**: Từ "shàng" có thể được gán nhãn là danh từ phương vị (f). Máy sẽ khó phân biệt đâu là danh từ chỉ phương hướng (như "phía bắc") và đâu là hư từ chỉ vị trí cần đảo. Sự nhập nhằng này làm phức tạp hóa thuật toán reordering.  
2. **Nhãn DEC vs DEG:**  
   * **CTB** phân biệt DEC (dùng trong mệnh đề quan hệ: "người **mà** tôi yêu" \- *wǒ ài **de** rén*) và DEG (dùng trong sở hữu: "sách **của** tôi" \- *wǒ **de** shū*).  
   * Mặc dù tiếng Việt có thể dịch cả hai là "của" hoặc "mà", nhưng về mặt cấu trúc cú pháp, mệnh đề quan hệ (DEC) đòi hỏi sự xử lý phức tạp hơn nhiều (đảo cả một mệnh đề động từ) so với sở hữu cách (DEG). Việc CTB tách biệt hai nhãn này cho phép bạn viết hai hàm xử lý riêng biệt, tăng độ chính xác.  
3. **Nhãn BA và LB (Bị động và Xử lý):**  
   CTB có nhãn riêng cho chữ "bả" (BA) và "bị" (LB \- long bei). Đây là các cấu trúc đặc thù của tiếng Trung hoàn toàn khác tiếng Việt. Việc nhận diện chính xác nhãn này cho phép chuyển đổi cấu trúc câu bị động tiếng Trung (Chủ ngữ \+ Bị \+ Tác nhân \+ Động từ) sang tiếng Việt (Chủ ngữ \+ Động từ \+ Bị \+ Tác nhân \- hoặc các biến thể khác) một cách hệ thống.

**Khuyến nghị:** Chọn **CTB**.

### **3.2 Named Entity Recognition (NER): Chọn OntoNotes 5.0**

Các lựa chọn: **MSRA**, **PKU**, **OntoNotes**.

| Đặc điểm | MSRA | OntoNotes 5.0 | PKU |
| :---- | :---- | :---- | :---- |
| **Số lượng nhãn** | 3 (PER, LOC, ORG) | **18** (PER, LOC, ORG, DATE, TIME, MONEY, PERCENT, CARDINAL...) | 3 cơ bản (tương tự MSRA) |
| **Khả năng xử lý số liệu** | Kém. Không nhận diện số/ngày tháng là thực thể. | **Xuất sắc**. Nhận diện cả cụm số liệu phức tạp. | Kém. |
| **Chiến lược dịch** | Dịch từng từ (dễ sai sót). | Dịch theo luật (Rule-based) hoặc Regex. | Dịch từng từ. |

#### **Phân tích Chi tiết: Sức mạnh của OntoNotes cho Dịch máy**

Trong dịch máy chuyên nghiệp, việc dịch sai số liệu, ngày tháng, tiền tệ là không thể chấp nhận được.

* **Vấn đề với MSRA/PKU:** Giả sử câu có cụm từ "ba mươi phần trăm" (bǎi fēn zhī sān shí).  
  * Mô hình MSRA không coi đây là thực thể. Bộ phân tích cú pháp sẽ tách nó thành: \[Cụm số: bǎi fēn\] \+ \+ \[Cụm số: sān shí\].  
  * Khi áp dụng luật đảo trật tự "Cụm danh từ", máy có thể đảo thành "sān shí zhī bǎi fēn" (ba mươi của phần trăm) hoặc các biến thể sai khác. Tiếng Việt cần dịch là "30%".  
* **Giải pháp OntoNotes:**  
  * Mô hình OntoNotes gán nhãn toàn bộ cụm "bǎi fēn zhī sān shí" là PERCENT.  
  * **Thuật toán của bạn:** Khi gặp nút cây có nhãn PERCENT, **dừng phân tích cú pháp sâu hơn**. Thay vào đó, chuyển chuỗi này cho một hàm xử lý riêng (formatter). Hàm này sẽ nhận diện mẫu và trả về "30%" hoặc "30 phần trăm" theo chuẩn tiếng Việt. Điều này đảm bảo độ chính xác tuyệt đối cho các dữ liệu định lượng.

Tương tự với DATE (Ngày tháng) và MONEY (Tiền tệ). Tiếng Trung nói "2023 năm 5 tháng", tiếng Việt nói "tháng 5 năm 2023". OntoNotes giúp đóng gói cụm này lại để xử lý bằng luật chuyển đổi ngày tháng chuyên biệt, thay vì phụ thuộc vào sự may rủi của cây cú pháp chung.  
**Khuyến nghị:** Chọn **OntoNotes 5.0**.

### **3.3 Constituency Parsing (CON): Chọn CTB**

Như đã đề cập ở phần POS, **CTB** là chuẩn vàng (Gold Standard) cho phân tích cú pháp thành phần tiếng Trung. Các mô hình tốt nhất của HanLP (như Electra, BERT) đều được huấn luyện trên CTB9. Việc chọn CON CTB là hiển nhiên để đồng bộ với POS CTB.

## ---

**4\. Kiến trúc Dữ liệu và Chiến lược Sắp xếp lại (Reordering Strategy)**

Sau khi đã chọn được các tác vụ (TOK, POS-CTB, NER-OntoNotes, CON-CTB), phần này sẽ mô tả chi tiết cách kết hợp chúng để tạo ra "cơ sở dữ liệu" mà người dùng yêu cầu: một Cây Cú pháp được làm giàu (Enriched Syntax Tree) và giải thuật xử lý nó.

### **4.1 Cấu trúc Dữ liệu Đầu ra (The Grammar Tree)**

Để phục vụ dịch máy, cây ngữ pháp của HanLP cần được chuyển đổi thành một đối tượng dữ liệu tùy biến (Custom Object) chứa đầy đủ thông tin từ các tác vụ khác.  
Một nút (Node) trong cây này cần chứa các trường thông tin sau:

1. **Label (Nhãn):** Nhãn cú pháp từ CON (ví dụ: NP, VP, CP) hoặc nhãn thực thể từ NER (ví dụ: ENT\_DATE, ENT\_ORG).  
2. **POS Tag:** (Chỉ dành cho nút lá) Nhãn từ loại từ CTB (ví dụ: NN, VV, LC).  
3. **Token:** (Chỉ dành cho nút lá) Từ vựng gốc tiếng Trung.  
4. **Children:** Danh sách các nút con.  
5. **Target\_Order:** Một chỉ số hoặc danh sách xác định thứ tự sau khi đảo (dùng để sinh câu tiếng Việt).

**Quy trình tích hợp:**

1. Chạy mô hình HanLP MTL để lấy cây Constituency (CON).  
2. Chạy NER OntoNotes để lấy danh sách các thực thể và vị trí của chúng (start\_index, end\_index).  
3. **Bước "Gộp Thực thể" (Entity Collapse):** Duyệt cây CON. Nếu một cây con (subtree) nằm trọn vẹn trong phạm vi của một thực thể NER (ví dụ: một NP chứa "Đại học Bắc Kinh"), hãy thu gọn toàn bộ cây con đó thành một nút lá duy nhất có nhãn NER (ví dụ: NER:ORG). Điều này ngăn cản việc đảo lộn từ ngữ bên trong tên riêng.

### **4.2 Các Mẫu Reordering Cốt lõi (Core Reordering Patterns)**

Dưới đây là bảng tổng hợp các quy tắc chuyển đổi cú pháp Trung-Việt dựa trên nhãn CTB mà hệ thống cần cài đặt:

| Cấu trúc | Nhãn CTB | Mẫu Tiếng Trung (Source) | Mẫu Tiếng Việt (Target) | Hành động Reordering |
| :---- | :---- | :---- | :---- | :---- |
| **Cụm Danh từ (Đơn giản)** | NP | Adjective (JJ) \+ Noun (NN) | Noun \+ Adjective | **Đảo ngược (Invert)**. |
| **Quan hệ Sở hữu** | DNP | NP (Sở hữu) \+ DEG (de) \+ NP (Vật) | NP (Vật) \+ \[của\] \+ NP (Sở hữu) | **Đảo ngược**. Thay DEG bằng từ "của". |
| **Mệnh đề Quan hệ** | CP | IP (Mệnh đề) \+ DEC (de) \+ NP (Danh từ) | NP (Danh từ) \+ \[mà\] \+ IP (Mệnh đề) | **Đảo ngược khối lớn**. Chuyển toàn bộ khối CP ra sau NP. Thay DEC bằng "mà". |
| **Cụm Phương vị** | LCP | NP (Danh từ) \+ LC (Phương vị) | \[Giới từ\] \+ NP (Danh từ) | **Đảo ngược**. Chuyển LC thành giới từ tiếng Việt tương ứng (shang-\>trên, xia-\>dưới). |
| **Cụm Giới từ (Trạng ngữ)** | PP \+ VP | \+ \[VP: Động từ\] | \[VP: Động từ\] \+ | **Di chuyển (Move)**. Tiếng Trung đặt trạng ngữ chỉ nơi chốn *trước* động từ. Tiếng Việt thường đặt *sau*. Chuyển nút PP xuống cuối VP. |
| **Câu chữ "Bả" (BA)** | BA | Chủ ngữ \+ BA \+ Tân ngữ \+ Động từ | Chủ ngữ \+ Động từ \+ Tân ngữ | **Tái cấu trúc**. Loại bỏ BA, chuyển Tân ngữ ra sau Động từ (về dạng SVO thường). |

### **4.3 Giải thuật Duyệt Cây và Đảo Vị trí**

Để thực hiện "tìm nghĩa và đảo lại vị trí", bạn cần sử dụng thuật toán duyệt cây theo chiều sâu (Depth-First Search), cụ thể là duyệt **Post-order** (Duyệt con trước, duyệt cha sau).  
**Pseudocode (Mã giả) cho quy trình:**

Python

def process\_node(node):  
    \# 1\. Đệ quy: Xử lý tất cả các con trước  
    for child in node.children:  
        process\_node(child)  
      
    \# 2\. Tại nút hiện tại, kiểm tra mẫu ngữ pháp để đảo  
    if node.label \== "NP":  
        apply\_noun\_phrase\_reordering(node)  
    elif node.label \== "LCP":  
        apply\_localizer\_reordering(node)  
    elif node.label \== "VP":  
        apply\_preposition\_movement(node)  
      
    \# 3\. Sau khi đảo cấu trúc, thực hiện dịch từ vựng (cho nút lá)  
    if node.is\_leaf():  
        translate\_leaf(node)

def translate\_leaf(node):  
    \# Sử dụng POS tag để chọn nghĩa trong từ điển  
    vietnamese\_word \= dictionary.lookup(word=node.token, pos=node.pos)  
    node.translated\_text \= vietnamese\_word

**Chi tiết về Tra cứu Từ điển (Dictionary Lookup):**  
Như người dùng yêu cầu, việc tra cứu phụ thuộc vào nhãn.

* Cơ sở dữ liệu từ điển của bạn phải có cấu trúc: Key: (Chinese\_Word, CTB\_POS\_Tag) \-\> Value: Vietnamese\_Meaning.  
* Ví dụ mục từ điển:  
  * ("shang", "LC"): "trên"  
  * ("shang", "VV"): "lên" (động từ)  
  * ("shang", "JJ"): "thượng/trước" (tính từ, như trong "thượng hải" hay "thượng tuần")  
* Khi cây cú pháp cung cấp nhãn LC cho từ "shang", hệ thống sẽ tự động chọn nghĩa "trên", loại bỏ hoàn toàn sự nhập nhằng.

## ---

**5\. Hướng dẫn Kỹ thuật: Tích hợp HanLP MTL (Code Concept)**

Dưới đây là hướng dẫn cụ thể về cách gọi mô hình HanLP với cấu hình đã chọn.

### **5.1 Tải Mô hình Joint MTL**

Thay vì tải từng mô hình riêng lẻ, bạn nên sử dụng mô hình "Close" MTL lớn nhất để tận dụng sức mạnh chia sẻ tri thức của Transformer (Electra).

Python

import hanlp

\# Tải mô hình đa nhiệm toàn diện (Bao gồm TOK, POS, NER, CON)  
\# Phiên bản ELECTRA BASE thường cho kết quả tốt nhất về ngữ nghĩa  
HanLP \= hanlp.load(hanlp.pretrained.mtl.CLOSE\_TOK\_POS\_NER\_SRL\_DEP\_SDP\_CON\_ELECTRA\_BASE\_ZH)

\# Văn bản đầu vào  
sentence \= "我在漂亮的北京大学读书。"   
\# (Tôi tại đẹp-de Bắc Kinh Đại học đọc sách) \-\> Tôi học ở Đại học Bắc Kinh đẹp.

\# Thực thi phân tích  
doc \= HanLP(sentence)

\# Trích xuất các lớp dữ liệu cần thiết  
\# 1\. Constituency Tree (Cây cú pháp)  
con\_tree \= doc\['con'\] 

\# 2\. NER (Chọn chuẩn OntoNotes như khuyến nghị)  
\# Lưu ý: Mô hình MTL này thường bao gồm cả msra và ontonotes.  
\# Hãy truy cập cụ thể vào key của ontonotes.  
ner\_entities \= doc\['ner/ontonotes'\] 

\# 3\. POS (Chuẩn CTB được tích hợp sẵn trong cây con)  
\# Bạn cũng có thể lấy chuỗi POS riêng nếu cần  
pos\_tags \= doc\['pos/ctb'\]

### **5.2 Xử lý OOV (Out-Of-Vocabulary) bằng Phân tích Cụm từ con**

Người dùng có yêu cầu: *"tìm nghĩa của các từ/cụm từ con rồi đảo lại"*. Đây là chiến lược dự phòng quan trọng khi từ điển không có sẵn cụm từ dài.  
Cây Constituency của HanLP hỗ trợ việc này rất tốt vì nó có tính phân cấp.

* Giả sử cụm (NP (NR A) (NN B)) không có trong từ điển cụm từ.  
* Hệ thống sẽ đi xuống nút con: tra A và tra B riêng biệt.  
* Sau đó áp dụng luật đảo của NP để ghép Dịch(B) \+ Dịch(A).  
* Quy trình này đảm bảo ngay cả khi gặp từ mới, miễn là cấu trúc ngữ pháp đúng, câu tiếng Việt đầu ra vẫn đúng trật tự (dù từ vựng có thể chưa mượt mà).

## ---

**6\. Kết luận và Lộ trình Thực hiện**

Để xây dựng cơ sở dữ liệu cú pháp cho máy dịch Trung-Việt theo yêu cầu, báo cáo đưa ra kết luận cuối cùng như sau:

1. **Mô hình:** Sử dụng **HanLP MTL** với kiến trúc **ELECTRA Base** để đạt độ chính xác cao nhất về cú pháp.  
2. **Tác vụ (Tasks):** Kích hoạt **TOK**, **POS**, **NER**, và **CON**. Bỏ qua DEP và SRL trong giai đoạn đầu vì không phục vụ trực tiếp cho việc đảo trật tự theo khối (block reordering).  
3. **Biến thể (Variants):**  
   * **POS \= CTB:** Để nắm bắt chính xác các hư từ chức năng (LC, DEC, BA) làm tín hiệu điều khiển việc đảo từ.  
   * **NER \= OntoNotes:** Để đóng gói và bảo vệ các dữ liệu định lượng (ngày, giờ, số, tiền) và tên riêng phức tạp, xử lý chúng bằng luật riêng thay vì đảo lộn.  
   * **CON \= CTB:** Để có cây cú pháp chuẩn mực, tương thích với POS.  
4. **Chiến lược:** Xây dựng thuật toán duyệt cây hậu thứ tự (Post-order traversal), kết hợp "Mặt nạ thực thể" (Entity Masking) từ NER để bảo vệ tên riêng, và sử dụng bảng luật ánh xạ cấu trúc Trung-Việt (Cụm danh từ ngược, Cụm giới từ trôi) để biến đổi cây trước khi tra từ điển.

Phương pháp tiếp cận này cung cấp một nền tảng vững chắc, kết hợp sức mạnh của học sâu (Deep Learning) trong phân tích cú pháp với sự kiểm soát chặt chẽ của các luật ngôn ngữ học (Linguistic Rules), phù hợp đặc thù cho cặp ngôn ngữ Trung-Việt.

#### **Works cited**

1. (PDF) A tree-to-string phrase-based model for statistical machine translation \- ResearchGate, accessed February 7, 2026, [https://www.researchgate.net/publication/228565799\_A\_tree-to-string\_phrase-based\_model\_for\_statistical\_machine\_translation](https://www.researchgate.net/publication/228565799_A_tree-to-string_phrase-based_model_for_statistical_machine_translation)  
2. Syntax Based Reordering with Automatically Derived Rules for Improved Statistical Machine Translation \- ACL Anthology, accessed February 7, 2026, [https://aclanthology.org/C10-1126.pdf](https://aclanthology.org/C10-1126.pdf)  
3. Chinese Syntactic Reordering for Statistical Machine Translation, accessed February 7, 2026, [http://www1.cs.columbia.edu/\~mcollins/papers/chineseReorder.pdf](http://www1.cs.columbia.edu/~mcollins/papers/chineseReorder.pdf)  
4. mtl — HanLP Documentation, accessed February 7, 2026, [https://hanlp.hankcs.com/docs/api/hanlp/pretrained/mtl.html](https://hanlp.hankcs.com/docs/api/hanlp/pretrained/mtl.html)  
5. HanLP 分词模型原创 \- CSDN博客, accessed February 7, 2026, [https://blog.csdn.net/m0\_47943986/article/details/127626843](https://blog.csdn.net/m0_47943986/article/details/127626843)  
6. Constituency Parsing and Dependency Parsing \- GeeksforGeeks, accessed February 7, 2026, [https://www.geeksforgeeks.org/compiler-design/constituency-parsing-and-dependency-parsing/](https://www.geeksforgeeks.org/compiler-design/constituency-parsing-and-dependency-parsing/)  
7. Constituency vs Dependency Parsing | Baeldung on Computer Science, accessed February 7, 2026, [https://www.baeldung.com/cs/constituency-vs-dependency-parsing](https://www.baeldung.com/cs/constituency-vs-dependency-parsing)  
8. LNAI 5459 \- Lexicalized Syntactic Reordering Framework for Word Alignment and Machine Translation \- Verbs Index, accessed February 7, 2026, [https://verbs.colorado.edu/\~wech5560/paper/2009\_ICCPOL.pdf](https://verbs.colorado.edu/~wech5560/paper/2009_ICCPOL.pdf)  
9. Training a Parser for Machine Translation Reordering \- Google Research, accessed February 7, 2026, [https://research.google.com/pubs/archive/37159.pdf](https://research.google.com/pubs/archive/37159.pdf)  
10. Constituency Parsing VS Dependency Parsing: | by 250\_VARUN EASWARAN IYER, accessed February 7, 2026, [https://medium.com/@varuniy22comp/constituency-parsing-vs-dependency-parsing-3d0855d6e8f5](https://medium.com/@varuniy22comp/constituency-parsing-vs-dependency-parsing-3d0855d6e8f5)  
11. Difference between constituency parser and dependency parser \- Stack Overflow, accessed February 7, 2026, [https://stackoverflow.com/questions/10401076/difference-between-constituency-parser-and-dependency-parser](https://stackoverflow.com/questions/10401076/difference-between-constituency-parser-and-dependency-parser)