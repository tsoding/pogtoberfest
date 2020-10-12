import std.stdio;
import std.net.curl;
import std.json;
import std.algorithm;
import std.file;
import std.string;
import std.array;
import std.conv;
import std.range;
import std.exception;

struct GitHub
{
    HTTP client;

    this(string token)
    {
        client = HTTP();
        client.addRequestHeader("User-Agent", "Pogtoberfest");
        client.addRequestHeader("Accept", "application/vnd.github.mercy-preview+json");
        client.addRequestHeader("Authorization", "token " ~ token);
    }

    string toString() const pure @safe
    {
        return "GitHub(\"DATA REDACTED\")";
    }
}

struct Org
{
    long public_repos;
}

struct Repo
{
    string owner;
    string name;
    string[] topics;

    void hacktoberfestify(GitHub github)
    {
        auto url = BASE_URL ~ "/repos/" ~ owner ~ "/" ~ name ~ "/topics";
        writeln(url);
        JSONValue payload = [
            "names": chain(topics, ["hacktoberfest", "hacktoberfest2020"]).array
        ];
        writeln(put(url, payload.toString, github.client));
    }

    void unhacktoberfestify(GitHub github)
    {
        auto url = BASE_URL ~ "/repos/" ~ owner ~ "/" ~ name ~ "/topics";
        writeln(url);
        JSONValue payload = [
            "names": topics.filter!(x => !startsWith(x, "hacktoberfest")).array
        ];
        writeln(put(url, payload.toString, github.client));
    }
}

immutable string BASE_URL = "https://api.github.com";

Org get_org(GitHub github, string owner)
{
    auto url = BASE_URL ~ "/orgs/" ~ owner;
    auto json = parseJSON(get(url, github.client));
    return Org(json["public_repos"].integer);
}

auto repos_of_owner(GitHub github, string owner, long page, long per_page)
{
    auto url = 
        BASE_URL ~ "/orgs/" ~ owner ~ "/repos" 
        ~ "?page=" ~ page.to!string 
        ~ "&per_page=" ~ per_page.to!string
        ~ "&type=public";
    auto content = get(url, github.client);
    return parseJSON(content)
        .array
        .map!(x => Repo(
            owner, 
            x["name"].str, 
            x["topics"].array.map!(y => y.str).array));
}

void usage(string error_message)
{
    stderr.writeln("Error: " ~ error_message);
    stderr.writeln("Usage: pogtoberfest <token-file> <organization> <hacktoberfestify|unhacktoberfestify>");
}

enum Command
{
    Hacktoberfestify,
    Unhacktoberfestify,
}

int main(string[] args)
{
    if (args.length < 4) {
        usage("Not enough arguments");
        return 1;
    }

    auto normalized_command = args[3].toLower.capitalize;
    Command command;
    try {
        command = parse!Command(normalized_command);
    } catch (Exception e) {
        usage("Unknown command `" ~ args[3] ~ "`");
        return 1;
    }
    GitHub github = strip(readText(args[1]));
    auto owner = args[2];
    const org = get_org(github, owner);
    const long PER_PAGE = 100;
    const long PAGE_COUNT = (org.public_repos + PER_PAGE - 1) / PER_PAGE;
    final switch (command) {
        case Command.Hacktoberfestify:
            foreach (i; 0..PAGE_COUNT) {
                foreach (repo; repos_of_owner(github, owner, i + 1, PER_PAGE)) {
                    repo.hacktoberfestify(github);
                }
            }
            break;
        case Command.Unhacktoberfestify:
            foreach (i; 0..PAGE_COUNT) {
                foreach (repo; repos_of_owner(github, owner, i + 1, PER_PAGE)) {
                    repo.unhacktoberfestify(github);
                }
            }
            break;
    }
    return 0;
}
