import 'package:flutter/material.dart';
import 'package:relay/core/model/api_request_model.dart';
import 'package:relay/features/home/presentation/widgets/home_requests_view.dart';

class HomeRequestsList extends StatelessWidget {
  const HomeRequestsList({
    super.key,
    required this.requests,
    required this.onTapRequest,
    required this.onEditRequest,
  });

  final List<ApiRequestModel> requests;
  final ValueChanged<ApiRequestModel> onTapRequest;
  final ValueChanged<ApiRequestModel> onEditRequest;

  @override
  Widget build(BuildContext context) {
    return HomeRequestsView(
      requests: requests,
      onTapRequest: onTapRequest,
      onEditRequest: onEditRequest,
    );
  }
}

