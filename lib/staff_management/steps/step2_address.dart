import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/staff_model.dart';
import '../../widgets/form_widgets.dart';

class Step2Address extends StatefulWidget {
  final StaffModel staff;
  final GlobalKey<FormState> formKey;

  const Step2Address({
    super.key,
    required this.staff,
    required this.formKey,
  });

  @override
  State<Step2Address> createState() => _Step2AddressState();
}

class _Step2AddressState extends State<Step2Address> {
  late final TextEditingController _addressCtrl;
  late final TextEditingController _villageCtrl;
  late final TextEditingController _districtCtrl;
  late final TextEditingController _pinCtrl;
  late final TextEditingController _mobile1Ctrl;
  late final TextEditingController _mobile2Ctrl;

  @override
  void initState() {
    super.initState();
    _addressCtrl = TextEditingController(text: widget.staff.address);
    _villageCtrl = TextEditingController(text: widget.staff.village);
    _districtCtrl = TextEditingController(text: widget.staff.district);
    _pinCtrl = TextEditingController(text: widget.staff.pin);
    _mobile1Ctrl = TextEditingController(text: widget.staff.mobileNo1);
    _mobile2Ctrl = TextEditingController(text: widget.staff.mobileNo2);
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _villageCtrl.dispose();
    _districtCtrl.dispose();
    _pinCtrl.dispose();
    _mobile1Ctrl.dispose();
    _mobile2Ctrl.dispose();
    super.dispose();
  }

  static const List<String> _indianStates = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
    'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram',
    'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu',
    'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
    'Delhi', 'Jammu & Kashmir', 'Ladakh', 'Puducherry', 'Chandigarh',
  ];

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionHeader(title: 'Address Details', icon: Icons.location_on),
          TextFormField(
            decoration: InputDecoration(label: Text('Full Address'),),
            controller: _addressCtrl,
            maxLines: 3,
            validator: (v) => v == null || v.isEmpty ? 'Address is required' : null,
            onChanged: (v) => widget.staff.address = v,
          ),
          TextFormField(
            decoration: InputDecoration(label: Text('Village / Town')),
            controller: _villageCtrl,
            onChanged: (v) => widget.staff.village = v,
          ),

          TextFormField(
            decoration: InputDecoration(label: Text('District')),
            controller: _districtCtrl,
            validator: (v) =>
                v == null || v.isEmpty ? 'District is required' : null,
            onChanged: (v) => widget.staff.district = v,
          ),

          FormDropdown(
            label: 'State',
            value: widget.staff.state,
            isRequired: true,
            items: _indianStates,
            validator: (v) =>
                v == null || v.isEmpty ? 'State is required' : null,
            onChanged: (v) => setState(() => widget.staff.state = v ?? ''),
          ),

          TextFormField(
            decoration: InputDecoration(label: Text('PIN Code')),
            controller: _pinCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: (v) {
              if (v == null || v.isEmpty) return 'PIN code is required';
              if (v.length != 6) return 'Enter valid 6-digit PIN';
              return null;
            },
            onChanged: (v) => widget.staff.pin = v,
          ),

          const SectionHeader(title: 'Contact Information', icon: Icons.phone),

          TextFormField(
            decoration: InputDecoration(label: Text('Mobile Number 1')),
            controller: _mobile1Ctrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: (v) {
              if (v == null || v.isEmpty) return 'Mobile number is required';
              if (v.length != 10) return 'Enter valid 10-digit mobile number';
              return null;
            },
            onChanged: (v) => widget.staff.mobileNo1 = v,
          ),

          TextFormField(
            decoration: InputDecoration(label: Text('Mobile Number 2 (Optional)')),
            controller: _mobile2Ctrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: (v) {
              if (v != null && v.isNotEmpty && v.length != 10) {
                return 'Enter valid 10-digit number';
              }
              return null;
            },
            onChanged: (v) => widget.staff.mobileNo2 = v,
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
