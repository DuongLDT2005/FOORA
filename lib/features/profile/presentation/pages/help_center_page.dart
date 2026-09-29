import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/components/app_header.dart';
import '../../../../shared/layouts/subpage_layout.dart';
import '../../../../shared/widgets/app_button.dart';

class HelpCenterPage extends StatefulWidget {
  const HelpCenterPage({super.key});

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'all';
  String _searchQuery = '';

  final List<Map<String, String>> _faqItems = const [
    {
      'category': 'receipt',
      'question': 'Tính năng Quét hóa đơn AI hoạt động như thế nào?',
      'answer':
          'FOORA sử dụng công nghệ thị giác máy tính và mô hình trí tuệ nhân tạo Google Gemini để tự động đọc hình ảnh hóa đơn từ siêu thị, chợ hoặc cửa hàng. Hệ thống tự động bóc tách tên thực phẩm, số lượng, ước tính vị trí bảo quản (tủ đông/tủ mát) và gợi ý ngày hết hạn dựa trên bộ quy tắc tiêu chuẩn.',
    },
    {
      'category': 'inventory',
      'question': 'Quy tắc FEFO là gì và giúp ích gì cho tôi?',
      'answer':
          'FEFO (First Expired, First Out - Hết hạn trước, Dùng trước) là phương pháp quản lý thông minh giúp bạn ưu tiên tiêu thụ những thực phẩm sắp tới hạn sử dụng trước, từ đó giảm thiểu tối đa lãng phí thức ăn và tiết kiệm chi phí cho gia đình.',
    },
    {
      'category': 'household',
      'question': 'Làm thế nào để chia sẻ tủ lạnh với thành viên gia đình?',
      'answer':
          'Bạn chỉ cần vào mục "Gia đình của tôi", chọn "Mời thành viên" và nhập mã hoặc chia sẻ liên kết lời mời. Khi người thân tham gia, mọi thay đổi thêm, sửa hoặc tiêu thụ thực phẩm sẽ được đồng bộ theo thời gian thực cho tất cả mọi người.',
    },
    {
      'category': 'membership',
      'question': 'Sự khác biệt giữa Gói Miễn phí và Gói Premium?',
      'answer':
          'Gói Miễn phí hỗ trợ lưu tối đa 50 món và 5 lượt quét hóa đơn AI mỗi tháng. Gói Premium mở khóa lưu trữ không giới hạn, không giới hạn quét AI, hỗ trợ lên tới 10 thành viên hộ gia đình và quyền ưu tiên hỗ trợ 24/7.',
    },
    {
      'category': 'receipt',
      'question': 'Nếu AI nhận diện sai tên món thì phải làm sao?',
      'answer':
          'Tại màn hình "Xem lại danh sách sau khi quét", bạn hoàn toàn có thể chỉnh sửa lại tên món, số lượng, ngày hết hạn hoặc xóa bỏ các mặt hàng không phải thực phẩm trước khi nhấn nút xác nhận lưu vào tủ.',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredFaqs = _faqItems.where((faq) {
      final matchesCat =
          _selectedCategory == 'all' || faq['category'] == _selectedCategory;
      final matchesQuery =
          _searchQuery.isEmpty ||
          faq['question']!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          faq['answer']!.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesQuery;
    }).toList();

    return SubpageLayout(
      header: AppHeader(
        title: 'Trung tâm trợ giúp',
        onBack: () => context.pop(),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppColors.slate200),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.slate900.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm câu hỏi thắc mắc...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.slate400,
                  ),
                  prefixIcon: const Icon(
                    LucideIcons.search,
                    color: AppColors.slate400,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14.h),
                ),
              ),
            ),
            SizedBox(height: 16.h),

            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChip('Tất cả', 'all'),
                  _buildChip('Quét hóa đơn AI', 'receipt'),
                  _buildChip('Kho & FEFO', 'inventory'),
                  _buildChip('Gia đình', 'household'),
                  _buildChip('Gói Premium', 'membership'),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // FAQ Accordion List
            Text(
              'Câu hỏi thường gặp (${filteredFaqs.length})',
              style: AppTextStyles.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.slate900,
              ),
            ),
            SizedBox(height: 12.h),

            if (filteredFaqs.isEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24.r),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: AppColors.slate100),
                ),
                child: Column(
                  children: [
                    Icon(
                      LucideIcons.helpCircle,
                      size: 36.r,
                      color: AppColors.slate300,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'Không tìm thấy câu hỏi phù hợp',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.slate700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: AppColors.slate100),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.r),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredFaqs.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.slate100,
                    ),
                    itemBuilder: (context, index) {
                      final item = filteredFaqs[index];
                      return Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 4.h,
                          ),
                          iconColor: AppColors.primary,
                          collapsedIconColor: AppColors.slate400,
                          title: Text(
                            item['question']!,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate800,
                            ),
                          ),
                          children: [
                            Padding(
                              padding: EdgeInsets.only(
                                left: 16.w,
                                right: 16.w,
                                bottom: 16.h,
                              ),
                              child: Text(
                                item['answer']!,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.slate600,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

            SizedBox(height: 28.h),

            // Contact CTA Card
            Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                color: AppColors.emerald50,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.emerald100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: const Icon(
                          LucideIcons.headset,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bạn vẫn cần trợ giúp?',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.slate900,
                              ),
                            ),
                            Text(
                              'Đội ngũ FOORA sẵn sàng hỗ trợ bạn bất kỳ lúc nào',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.slate600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  AppButton.primary(
                    label: 'Liên hệ bộ phận hỗ trợ',
                    icon: LucideIcons.messageSquare,
                    onPressed: () {
                      context.push(AppRouteNames.contactUs);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, String value) {
    final isSelected = _selectedCategory == value;
    return Padding(
      padding: EdgeInsets.only(right: 8.w),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = value),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.slate200,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: isSelected ? Colors.white : AppColors.slate600,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
