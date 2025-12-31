import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/user.dart';
import '../../widgets/custom_app_bar.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  String? _selectedGender;
  DateTime? _selectedDateOfBirth;
  String? _selectedKCC;
  String? _selectedDepartment;
  String? _selectedMembershipStatus;
  CountryCode _selectedCountryCode = CountryCode.countries.first;
  String? _profilePhotoUrl;

  final List<String> _genderOptions = ['Male', 'Female'];
  final List<String> _kccOptions = [
    'Akobo KCC',
    'Bodija1 KCC',
    'Bodija 2 KCC',
    'Ojoo KCC',
    'Sango KCC',
    'Ring Road KCC',
    'Agbowo KCC',
    'Bashorun KCC',
  ];
  final List<String> _departmentOptions = [
    'Choir',
    'Ushering',
    'Technical',
    'Media',
    'Protocol',
    'Children Ministry',
    'Welfare',
    'Evangelism',
    'Prayer',
    'Hospitality',
    'Security',
  ];
  final List<String> _membershipStatusOptions = [
    'pending',
    'Member',
    'Worker',
    'Volunteer',
    'Visitor',
    'Pastorate',
  ];

  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _firstNameController.text = user.firstName;
      _middleNameController.text = user.middleName ?? '';
      _lastNameController.text = user.lastName;
      _emailController.text = user.email;
      _phoneController.text = user.phoneNumber ?? '';
      _addressController.text = user.address ?? '';
      _selectedGender = user.gender;
      _selectedDateOfBirth = user.dateOfBirth;
      _selectedKCC = user.kcc;
      _selectedDepartment = user.department;
      _selectedMembershipStatus = user.membershipStatus;
      _profilePhotoUrl = user.photoUrl;
      
      // Set country code if available
      if (user.countryCode != null) {
        final matchingCountry = CountryCode.countries.where(
          (c) => c.dialCode == user.countryCode
        ).firstOrNull;
        if (matchingCountry != null) {
          _selectedCountryCode = matchingCountry;
        }
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Edit Profile', showBackButton: true),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfilePhotoSection(context, isDark),
                const SizedBox(height: 32),
                _buildSectionTitle(context, 'Personal Information'),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _firstNameController,
                  label: 'First Name',
                  hint: 'Enter your first name',
                  isDark: isDark,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'First name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _middleNameController,
                  label: 'Middle Name',
                  hint: 'Enter your middle name (optional)',
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _lastNameController,
                  label: 'Last Name',
                  hint: 'Enter your last name',
                  isDark: isDark,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Last name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  hint: 'Enter your email',
                  isDark: isDark,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email is required';
                    }
                    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                    if (!emailRegex.hasMatch(value)) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildPhoneField(isDark),
                const SizedBox(height: 16),
                _buildDropdownField(
                  label: 'Gender',
                  value: _selectedGender,
                  items: _genderOptions,
                  isDark: isDark,
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildDateField(context, isDark),
                const SizedBox(height: 32),
                _buildSectionTitle(context, 'Church Information'),
                const SizedBox(height: 16),
                _buildDropdownField(
                  label: 'KCC (Kingdom Community Center)',
                  value: _selectedKCC,
                  items: _kccOptions,
                  isDark: isDark,
                  onChanged: (value) {
                    setState(() {
                      _selectedKCC = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildDropdownField(
                  label: 'Department/Unit',
                  value: _selectedDepartment,
                  items: _departmentOptions,
                  isDark: isDark,
                  onChanged: (value) {
                    setState(() {
                      _selectedDepartment = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildDropdownField(
                  label: 'Membership Status',
                  value: _selectedMembershipStatus,
                  items: _membershipStatusOptions,
                  isDark: isDark,
                  onChanged: (value) {
                    setState(() {
                      _selectedMembershipStatus = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _addressController,
                  label: 'Address',
                  hint: 'Enter your residential address',
                  isDark: isDark,
                  maxLines: 3,
                ),
                const SizedBox(height: 32),
                _buildSectionTitle(context, 'Security'),
                const SizedBox(height: 16),
                _buildBiometricToggle(context, isDark),
                const SizedBox(height: 32),
                _buildSaveButton(context),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePhotoSection(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: isDark ? AppColors.cardDark : Colors.grey[200],
                backgroundImage:
                    _profilePhotoUrl != null ? NetworkImage(_profilePhotoUrl!) : null,
                child: _profilePhotoUrl == null
                    ? Icon(
                        Icons.person,
                        size: 60,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _showPhotoOptions(context, isDark),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.backgroundDark : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _showPhotoOptions(context, isDark),
            child: const Text(
              'Change Profile Photo',
              style: TextStyle(
                color: AppColors.primaryGold,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPhotoOptions(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primaryGold),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement camera capture
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primaryGold),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement gallery picker
                },
              ),
              if (_profilePhotoUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: AppColors.error),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _profilePhotoUrl = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.primaryGold,
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: isDark ? AppColors.cardDark : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryGold, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone Number',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            GestureDetector(
              onTap: () => _showCountryCodePicker(context, isDark),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedCountryCode.flag,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedCountryCode.dialCode,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: 'Enter phone number',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: isDark ? AppColors.cardDark : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryGold, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showCountryCodePicker(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Country',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: CountryCode.countries.length,
                itemBuilder: (context, index) {
                  final country = CountryCode.countries[index];
                  return ListTile(
                    leading: Text(country.flag, style: const TextStyle(fontSize: 24)),
                    title: Text(country.name),
                    trailing: Text(
                      country.dialCode,
                      style: const TextStyle(color: AppColors.primaryGold),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedCountryCode = country;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required bool isDark,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            hint: Text(
              'Select $label',
              style: TextStyle(color: Colors.grey[400]),
            ),
            dropdownColor: isDark ? AppColors.cardDark : Colors.white,
            items: items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(item),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date of Birth',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDateOfBirth ?? DateTime(2000),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                          primary: AppColors.primaryGold,
                        ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              setState(() {
                _selectedDateOfBirth = date;
              });
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDateOfBirth != null
                      ? '${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.year}'
                      : 'Select date of birth',
                  style: TextStyle(
                    color: _selectedDateOfBirth != null
                        ? (isDark ? Colors.white : Colors.black)
                        : Colors.grey[400],
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  color: Colors.grey[600],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBiometricToggle(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.fingerprint,
              color: AppColors.primaryGold,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Biometric Authentication',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Use fingerprint or face ID to login',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                ),
              ],
            ),
          ),
          Switch(
            value: _biometricEnabled,
            onChanged: (value) {
              setState(() {
                _biometricEnabled = value;
              });
              if (value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Biometric authentication enabled'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            activeColor: AppColors.primaryGold,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGold,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Update Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState?.validate() ?? false) {
      final authProvider = context.read<AuthProvider>();
      
      final profileData = {
        'first_name': _firstNameController.text.trim(),
        'middle_name': _middleNameController.text.trim().isEmpty 
            ? null 
            : _middleNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone_number': _phoneController.text.trim().isEmpty 
            ? null 
            : _phoneController.text.trim(),
        'country_code': _selectedCountryCode.dialCode,
        'gender': _selectedGender,
        'date_of_birth': _selectedDateOfBirth?.toIso8601String().split('T').first,
        'kcc': _selectedKCC,
        'department': _selectedDepartment,
        'membership_status': _selectedMembershipStatus,
        'address': _addressController.text.trim().isEmpty 
            ? null 
            : _addressController.text.trim(),
      };
      
      final success = await authProvider.updateProfile(profileData);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.error ?? 'Failed to update profile'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}
