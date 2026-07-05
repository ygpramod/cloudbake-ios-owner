import XCTest
@testable import CloudBakeOwner

@MainActor
final class CustomerListViewModelTests: XCTestCase {
    func testLoadFetchesCustomers() {
        let repository = FakeCustomerRepository()
        let customer = Customer(
            id: "customer-amy",
            name: "Amy",
            phone: "5550101",
            email: nil,
            address: nil,
            likes: nil,
            dislikes: nil,
            allergies: nil,
            dietaryRestrictions: nil,
            notes: nil,
            createdAt: Date(timeIntervalSince1970: 1_800_060_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_060_000)
        )
        repository.customers = [customer]
        let viewModel = CustomerListViewModel(repository: repository)

        viewModel.load()

        XCTAssertEqual(viewModel.customers, [customer])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testAddCustomerPersistsRequiredAndOptionalFields() {
        let repository = FakeCustomerRepository()
        let now = Date(timeIntervalSince1970: 1_800_060_000)
        var ids = ["customer-amy", "customer-date-birthday"]
        let viewModel = CustomerListViewModel(
            repository: repository,
            idGenerator: { ids.removeFirst() },
            dateProvider: { now }
        )
        viewModel.draftName = " Amy "
        viewModel.draftPhone = " 5550101 "
        viewModel.draftEmail = " amy@example.com "
        viewModel.draftAddress = " 10 Cake Street "
        viewModel.draftLikes = " Vanilla "
        viewModel.draftDislikes = " Fondant "
        viewModel.draftAllergies = " Nuts "
        viewModel.draftDietaryRestrictions = " Eggless "
        viewModel.draftNotes = " Prefers less sweet frosting "
        viewModel.draftImportantDateLabel = " Birthday "
        viewModel.draftImportantDate = Date(timeIntervalSince1970: 1_801_000_000)

        XCTAssertTrue(viewModel.addCustomer())

        let expectedCustomer = Customer(
            id: "customer-amy",
            name: "Amy",
            phone: "5550101",
            email: "amy@example.com",
            address: "10 Cake Street",
            likes: "Vanilla",
            dislikes: "Fondant",
            allergies: "Nuts",
            dietaryRestrictions: "Eggless",
            notes: "Prefers less sweet frosting",
            createdAt: now,
            updatedAt: now
        )
        XCTAssertEqual(repository.customers, [expectedCustomer])
        XCTAssertEqual(
            repository.importantDates,
            [
                CustomerImportantDate(
                    id: "customer-date-birthday",
                    customerId: "customer-amy",
                    label: "Birthday",
                    date: Date(timeIntervalSince1970: 1_801_000_000),
                    createdAt: now,
                    updatedAt: now
                )
            ]
        )
        XCTAssertEqual(viewModel.customers, [expectedCustomer])
        XCTAssertEqual(viewModel.draftName, "")
        XCTAssertEqual(viewModel.draftPhone, "")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testAddCustomerRequiresNameAndPhone() {
        let repository = FakeCustomerRepository()
        let viewModel = CustomerListViewModel(repository: repository)

        viewModel.draftName = " "
        viewModel.draftPhone = "5550101"
        XCTAssertFalse(viewModel.addCustomer())
        XCTAssertEqual(viewModel.errorMessage, "Customer name is required.")

        viewModel.draftName = "Amy"
        viewModel.draftPhone = " "
        XCTAssertFalse(viewModel.addCustomer())
        XCTAssertEqual(viewModel.errorMessage, "Customer phone is required.")
        XCTAssertTrue(repository.customers.isEmpty)
    }

    func testBeginAddingCustomerAppliesImportedDraftWithoutSaving() {
        let repository = FakeCustomerRepository()
        let importantDate = Date(timeIntervalSince1970: 1_801_000_000)
        let viewModel = CustomerListViewModel(repository: repository)

        viewModel.beginAddingCustomer(
            importedDraft: CustomerContactDraft(
                name: "Amy Baker",
                phone: "5550101",
                email: "amy@example.com",
                address: "10 Cake Street",
                importantDateLabel: "Birthday",
                importantDate: importantDate
            )
        )

        XCTAssertEqual(viewModel.draftName, "Amy Baker")
        XCTAssertEqual(viewModel.draftPhone, "5550101")
        XCTAssertEqual(viewModel.draftEmail, "amy@example.com")
        XCTAssertEqual(viewModel.draftAddress, "10 Cake Street")
        XCTAssertEqual(viewModel.draftImportantDateLabel, "Birthday")
        XCTAssertEqual(viewModel.draftImportantDate, importantDate)
        XCTAssertTrue(repository.customers.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.duplicateWarningMessage)
    }

    func testAddCustomerWarnsBeforeSavingDuplicate() {
        let repository = FakeCustomerRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        repository.customers = [
            Customer(
                id: "customer-amy",
                name: "Amy",
                phone: "5550101",
                email: nil,
                address: nil,
                likes: nil,
                dislikes: nil,
                allergies: nil,
                dietaryRestrictions: nil,
                notes: nil,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        ]
        let viewModel = CustomerListViewModel(
            repository: repository,
            idGenerator: { "customer-duplicate" },
            dateProvider: { timestamp }
        )
        viewModel.load()
        viewModel.draftName = "Amy"
        viewModel.draftPhone = "5550101"

        XCTAssertFalse(viewModel.addCustomer())
        XCTAssertEqual(
            viewModel.duplicateWarningMessage,
            "Possible duplicate: Amy already exists. Tap Save again to add a separate customer."
        )
        XCTAssertEqual(repository.customers.count, 1)

        XCTAssertTrue(viewModel.addCustomer())
        XCTAssertEqual(repository.customers.count, 2)
        XCTAssertNil(viewModel.duplicateWarningMessage)
    }

    func testBeginViewingCustomerLoadsImportantDatesAndOrders() {
        let repository = FakeCustomerRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        let customer = Customer(
            id: "customer-amy",
            name: "Amy",
            phone: "5550101",
            email: nil,
            address: nil,
            likes: nil,
            dislikes: nil,
            allergies: nil,
            dietaryRestrictions: nil,
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let importantDate = CustomerImportantDate(
            id: "date-birthday",
            customerId: customer.id,
            label: "Birthday",
            date: Date(timeIntervalSince1970: 1_801_000_000),
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let secondOrder = makeOrder(
            id: "order-chocolate",
            customerId: customer.id,
            title: "Chocolate Anniversary",
            dueAt: Date(timeIntervalSince1970: 1_800_180_000)
        )
        let firstOrder = makeOrder(
            id: "order-vanilla",
            customerId: customer.id,
            title: "Vanilla Birthday",
            dueAt: Date(timeIntervalSince1970: 1_800_140_000)
        )
        let unrelatedOrder = makeOrder(
            id: "order-other",
            customerId: "customer-zoe",
            title: "Other Cake",
            dueAt: Date(timeIntervalSince1970: 1_800_120_000)
        )
        repository.importantDates = [importantDate]
        repository.orders = [secondOrder, unrelatedOrder, firstOrder]
        let viewModel = CustomerListViewModel(repository: repository)

        viewModel.beginViewingCustomer(customer)

        XCTAssertEqual(viewModel.selectedCustomer, customer)
        XCTAssertEqual(viewModel.selectedCustomerImportantDates, [importantDate])
        XCTAssertEqual(viewModel.selectedCustomerOrders, [firstOrder, secondOrder])

        viewModel.closeCustomerDetail()

        XCTAssertNil(viewModel.selectedCustomer)
        XCTAssertTrue(viewModel.selectedCustomerImportantDates.isEmpty)
        XCTAssertTrue(viewModel.selectedCustomerOrders.isEmpty)
    }

    func testSaveEditedCustomerPersistsFieldsAndPreservesCreatedAt() {
        let repository = FakeCustomerRepository()
        let createdAt = Date(timeIntervalSince1970: 1_800_060_000)
        let updatedAt = Date(timeIntervalSince1970: 1_800_061_000)
        let customer = Customer(
            id: "customer-amy",
            name: "Amy",
            phone: "5550101",
            email: nil,
            address: nil,
            likes: nil,
            dislikes: nil,
            allergies: "Nuts",
            dietaryRestrictions: nil,
            notes: nil,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        repository.customers = [customer]
        let viewModel = CustomerListViewModel(
            repository: repository,
            dateProvider: { updatedAt }
        )
        viewModel.load()
        viewModel.beginViewingCustomer(customer)
        viewModel.beginEditingCustomer()
        viewModel.draftName = " Amy B "
        viewModel.draftPhone = " 5550102 "
        viewModel.draftEmail = " amy@example.com "
        viewModel.draftAddress = " 10 Cake Street "
        viewModel.draftLikes = " Vanilla "
        viewModel.draftAllergies = " "
        viewModel.draftNotes = " Less sweet "

        XCTAssertTrue(viewModel.saveEditedCustomer())

        let edited = Customer(
            id: customer.id,
            name: "Amy B",
            phone: "5550102",
            email: "amy@example.com",
            address: "10 Cake Street",
            likes: "Vanilla",
            dislikes: nil,
            allergies: nil,
            dietaryRestrictions: nil,
            notes: "Less sweet",
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        XCTAssertEqual(repository.customers, [edited])
        XCTAssertEqual(viewModel.selectedCustomer, edited)
        XCTAssertEqual(viewModel.customers, [edited])
        XCTAssertNil(viewModel.editingCustomer)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testSaveEditedCustomerWarnsBeforeUsingAnotherCustomersPhone() {
        let repository = FakeCustomerRepository()
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        let amy = Customer(
            id: "customer-amy",
            name: "Amy",
            phone: "5550101",
            email: nil,
            address: nil,
            likes: nil,
            dislikes: nil,
            allergies: nil,
            dietaryRestrictions: nil,
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let zoe = Customer(
            id: "customer-zoe",
            name: "Zoe",
            phone: "5550102",
            email: nil,
            address: nil,
            likes: nil,
            dislikes: nil,
            allergies: nil,
            dietaryRestrictions: nil,
            notes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        repository.customers = [amy, zoe]
        let viewModel = CustomerListViewModel(repository: repository)
        viewModel.load()
        viewModel.beginViewingCustomer(amy)
        viewModel.beginEditingCustomer()
        viewModel.draftPhone = "5550102"

        XCTAssertFalse(viewModel.saveEditedCustomer())
        XCTAssertEqual(
            viewModel.duplicateWarningMessage,
            "Possible duplicate: Zoe already exists. Tap Save again to keep this customer separate."
        )
        XCTAssertEqual(repository.customers, [amy, zoe])
    }

    private func makeOrder(
        id: String,
        customerId: String,
        title: String,
        dueAt: Date
    ) -> Order {
        let timestamp = Date(timeIntervalSince1970: 1_800_060_000)
        return Order(
            id: id,
            customerId: customerId,
            cakeDesignId: nil,
            title: title,
            customerName: "Amy",
            status: .confirmed,
            dueAt: dueAt,
            fulfillmentType: .pickup,
            deliveryAddress: nil,
            cakeNotes: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }
}

private final class FakeCustomerRepository: CustomerRepository, CustomerImportantDateRepository, OrderRepository {
    var customers: [Customer] = []
    var importantDates: [CustomerImportantDate] = []
    var orders: [Order] = []

    func save(_ customer: Customer) throws {
        customers.removeAll { $0.id == customer.id }
        customers.append(customer)
    }

    func fetchCustomer(id: String) throws -> Customer? {
        customers.first { $0.id == id }
    }

    func fetchCustomers() throws -> [Customer] {
        customers
    }

    func save(_ importantDate: CustomerImportantDate) throws {
        importantDates.removeAll { $0.id == importantDate.id }
        importantDates.append(importantDate)
    }

    func fetchCustomerImportantDates(customerId: String) throws -> [CustomerImportantDate] {
        importantDates.filter { $0.customerId == customerId }
    }

    func save(_ order: Order) throws {
        orders.removeAll { $0.id == order.id }
        orders.append(order)
    }

    func fetchOrder(id: String) throws -> Order? {
        orders.first { $0.id == id }
    }

    func fetchOrders() throws -> [Order] {
        orders.sorted { lhs, rhs in
            lhs.dueAt == rhs.dueAt ? lhs.title < rhs.title : lhs.dueAt < rhs.dueAt
        }
    }
}
