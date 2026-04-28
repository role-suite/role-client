import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/models/request_enums.dart';
import 'package:relay/core/utils/extension.dart';
import 'package:relay/features/home/request/presentation/controllers/request_form_controller.dart';

void main() {
  test('controller starts with one editable row for headers, params and form-data', () {
    final controller = RequestFormController(initialCollectionId: 'default');
    addTearDown(controller.dispose);

    expect(controller.headerKeyControllers.length, 1);
    expect(controller.paramKeyControllers.length, 1);
    expect(controller.formDataKeyControllers.length, 1);
  });

  test('build helpers trim keys and ignore empty entries', () {
    final controller = RequestFormController(initialCollectionId: 'default');
    addTearDown(controller.dispose);

    controller.headerKeyControllers.first.text = '  X-Trace  ';
    controller.headerValueControllers.first.text = ' id-1 ';
    controller.addHeaderRow(key: ' ', value: 'ignored');

    controller.paramKeyControllers.first.text = ' page ';
    controller.paramValueControllers.first.text = ' 1 ';

    controller.formDataKeyControllers.first.text = ' file ';
    controller.formDataValueControllers.first.text = ' invoice.pdf ';

    expect(controller.buildHeaders(), {'X-Trace': 'id-1'});
    expect(controller.buildParams(), {'page': '1'});
    expect(controller.buildFormDataFields(), {'file': 'invoice.pdf'});
  });

  test('buildAuthConfig handles auth modes and required fields', () {
    final controller = RequestFormController(initialCollectionId: 'default');
    addTearDown(controller.dispose);

    controller.selectedAuthType = AuthType.basic;
    controller.authUsernameController.text = ' user ';
    controller.authPasswordController.text = ' pass ';
    expect(controller.buildAuthConfig(), {
      AuthConfigKeys.username: 'user',
      AuthConfigKeys.password: 'pass',
    });

    controller.selectedAuthType = AuthType.apiKey;
    controller.authApiKeyHeaderController.text = ' ';
    controller.authApiKeyValueController.text = 'abc';
    expect(controller.buildAuthConfig(), isEmpty);
  });

  test('validateRequiredFields and buildRequest use selected values', () {
    final controller = RequestFormController(initialCollectionId: null);
    addTearDown(controller.dispose);

    expect(controller.validateRequiredFields(), 'Please fill in all required fields');

    controller.nameController.text = 'List users';
    controller.urlController.text = 'https://example.com/users';
    controller.selectedCollectionId = 'default';
    controller.selectedMethod = HttpMethod.patch;
    controller.selectedBodyType = BodyType.raw;
    controller.bodyController.text = '  '; // should become null

    expect(controller.validateRequiredFields(), isNull);

    final request = controller.buildRequest();
    expect(request.id, isNotEmpty);
    expect(request.name, 'List users');
    expect(request.urlTemplate, 'https://example.com/users');
    expect(request.method, HttpMethod.patch);
    expect(request.collectionId, 'default');
    expect(request.body, isNull);
  });

  test('findEnvironmentByName finds matching environment', () {
    final controller = RequestFormController(initialCollectionId: 'default');
    addTearDown(controller.dispose);

    final envs = [
      EnvironmentModel(name: 'dev', variables: {'baseUrl': 'https://dev.example.com'}),
      EnvironmentModel(name: 'prod', variables: {'baseUrl': 'https://prod.example.com'}),
    ];

    expect(controller.findEnvironmentByName(envs, 'prod')?.name, 'prod');
    expect(controller.findEnvironmentByName(envs, 'missing'), isNull);
  });
}
