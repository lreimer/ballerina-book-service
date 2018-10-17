import ballerina/http;
import ballerina/io;
import ballerinax/docker;
import ballerinax/kubernetes;

@docker:Config {
    name:"lreimer/ballerina-book-service",
    tag:"1.0.0"
}
@docker:Expose {}
@kubernetes:Service {
    serviceType:"NodePort",
    name:"ballerina-book-service"
}
@kubernetes:Deployment {
    image:"lreimer/ballerina-book-service:1.0.0",
    name:"ballerina-book-service"
}
endpoint http:Listener listener {
    port:9090
};

// Book management is done using an in-memory map.
map<json> booksMap;

@http:ServiceConfig { basePath: "/" }
service<http:Service> library bind listener {

    // Resource that handles the HTTP GET requests that are directed to the
    // list of books using path '/books'
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/books"
    }
    getBooks(endpoint client, http:Request req) {
        io:println("GET list of books.");

        int i = 0;
        json books = [];
        foreach b in booksMap.values() {
            books[i] = check <json>b;
            i = i + 1;
        }

        http:Response response;
        response.statusCode = 200;
        response.setJsonPayload(untaint books);

        _ = client->respond(response);
    }

    // Resource that handles the HTTP POST requests that are directed to the path
    // '/books' to create a new book.
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/books"
    }
    createBook(endpoint client, http:Request req) {

        json bookReq = check req.getJsonPayload();
        string isbn13 = bookReq.isbn13.toString();
        booksMap[isbn13] = bookReq;

        io:println("POST new book with ISBN-13 " + isbn13);

        http:Response response;
        response.statusCode = 201;
        response.setHeader("Location", "http://localhost:9090/books/" + isbn13);

        _ = client->respond(response);
    }

    // Resource that handles the HTTP GET requests that are directed to a specific
    // book using path '/books/<isbn13>'
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/books/{isbn13}"
    }
    getBook(endpoint client, http:Request req, string isbn13) {
        io:println("GET book with ISBN-13 " + isbn13);

        json? payload = booksMap[isbn13];
        http:Response response;
        if (payload == null) {
            response.statusCode = 404;
        } else {
            response.setJsonPayload(untaint payload);
        }
        _ = client->respond(response);
    }

    // Resource that handles the HTTP PUT requests that are directed to the path
    // '/books/<isbn13>' to update an existing Book.
    @http:ResourceConfig {
        methods: ["PUT"],
        path: "/books/{isbn13}"
    }
    updateBook(endpoint client, http:Request req, string isbn13) {
        json updatedBook = check req.getJsonPayload();
        json existingBook = booksMap[isbn13];
        http:Response response;

        if (existingBook != null) {
            io:println("PUT updated book with ISBN-13 " + isbn13);

            existingBook.name = updatedBook.name;
            existingBook.author = updatedBook.author;
            booksMap[isbn13] = existingBook;
        } else {
            response.statusCode = 404;
        }

        _ = client->respond(response);
    }

    // Resource that handles the HTTP DELETE requests, which are directed to the path
    // '/books/<isbn13>' to delete an existing Book.
    @http:ResourceConfig {
        methods: ["DELETE"],
        path: "/books/{isbn13}"
    }
    deleteBook(endpoint client, http:Request req, string isbn13) {
        io:println("DELETE book with ISBN-13 " + isbn13);

        http:Response response;
        _ = booksMap.remove(isbn13);
        _ = client->respond(response);
    }
}